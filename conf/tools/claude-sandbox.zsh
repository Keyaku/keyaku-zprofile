#!/usr/bin/env zsh

# claude-sandbox — provisions a least-privilege `claude` automation user for
# running Claude Code, plus the constrained Docker-control wrapper it uses.
#
# Idempotent; safe to re-run. Run as root (re-execs via sudo if needed):
#   conf/tools/claude-sandbox.zsh
#
# What it sets up:
#   1. A `claude` system user (own home, bash) in adm + systemd-journal (log
#      reads) and the project group (read/write the Docker working tree).
#   2. claude's bash XDG env so Claude Code finds its config under the home.
#   3. /usr/local/bin/claude-run  — launcher (run Claude Code as `claude`).
#   4. /usr/local/bin/dctl        — arg-validating Docker control wrapper.
#   5. /usr/local/bin/claude-ctx  — SessionStart profile emitter.
#   6. /etc/sudoers.d/10-claude-run + 99-claude — the two sudo policies:
#        * the launching user may run claude-run AS claude (never root)
#        * `claude` gets a read-only diagnostic allowlist + non-escalating
#          container lifecycle + the dctl wrapper. Raw mutating docker is NOT
#          granted; escalating verbs (exec/rm/compose up) go through dctl.
#
# Everything escalating is gated by argument validation in dctl rather than by
# sudo wildcards, because the Docker CLI is a root-equivalent API: an `exec`,
# `run` or `compose up` wildcard is trivial host root (-v /:/host, a
# socket-mounting container, or an attacker-authored compose file).

emulate -L zsh
setopt pipefail extendedglob

### CONSTANTS — override via the environment to retarget another machine.

readonly THIS=${0:t}

# The automation user. Only this name is ever referenced by design.
: ${CLAUDE_USER:=claude}
: ${CLAUDE_HOME:=/home/${CLAUDE_USER}}

# The launching account that may `sudo -u claude claude-run`. Defaults to
# whoever invoked this script under sudo (never hardcoded).
: ${CLAUDE_LAUNCHER:=${SUDO_USER:-}}

# The Docker project working tree. Its stacks/ subdir is the only place dctl
# will act on an on-disk compose file. The group owning it is the file-access
# group claude joins. Intentionally NO default — it is prompted for (or taken
# from the environment) so no single host's layout is presumed. CLAUDE_STACKS
# derives from it unless overridden.

say()  { print -r -- "${THIS}: $*"; }
die()  { print -ru2 -- "${THIS}: error: $*"; exit 1; }

# Prompt for the project tree if it was not supplied via the environment. Done
# before the sudo re-exec so it uses the invoking user's terminal and is then
# carried across the boundary.
if [[ -z ${CLAUDE_PROJECT_DIR:-} ]]; then
	print -n "Path to the Docker project working tree (holds the stacks/ subdir): "
	read -r CLAUDE_PROJECT_DIR || die "no project directory given"
fi
[[ -n $CLAUDE_PROJECT_DIR ]]   || die "a project directory is required"
[[ $CLAUDE_PROJECT_DIR == /* ]] || die "CLAUDE_PROJECT_DIR must be an absolute path (got '$CLAUDE_PROJECT_DIR')"
: ${CLAUDE_STACKS:=${CLAUDE_PROJECT_DIR}/stacks}

# Re-exec as root if we are not already.
if (( EUID != 0 )); then
	command -v sudo >/dev/null || die "must run as root and sudo is unavailable"
	# Preserve the resolved launcher across the sudo boundary.
	exec sudo CLAUDE_LAUNCHER="${CLAUDE_LAUNCHER:-$USER}" \
		CLAUDE_USER="$CLAUDE_USER" CLAUDE_HOME="$CLAUDE_HOME" \
		CLAUDE_PROJECT_DIR="$CLAUDE_PROJECT_DIR" CLAUDE_STACKS="$CLAUDE_STACKS" \
		zsh "${0:A}" "$@"
fi

[[ -n $CLAUDE_LAUNCHER ]] || die "set CLAUDE_LAUNCHER to the account that launches Claude Code"
command -v docker >/dev/null || say "warning: docker not found — dctl/lifecycle rules will be inert until installed"

### Derive the file-access group from the project tree's owner group.

if [[ -d $CLAUDE_PROJECT_DIR ]]; then
	PROJECT_GROUP=$(stat -c '%G' "$CLAUDE_PROJECT_DIR")
else
	PROJECT_GROUP=$(id -gn "$CLAUDE_LAUNCHER" 2>/dev/null) \
		|| die "project dir $CLAUDE_PROJECT_DIR absent and launcher group undeterminable"
	say "note: $CLAUDE_PROJECT_DIR absent; using launcher's primary group '$PROJECT_GROUP' for file access"
fi

####################
# 1. User + groups
####################

extra_groups=(adm systemd-journal "$PROJECT_GROUP")
# Keep only groups that actually exist on this host.
present_groups=()
for g in $extra_groups; do getent group "$g" >/dev/null && present_groups+=("$g"); done

if id "$CLAUDE_USER" >/dev/null 2>&1; then
	usermod -aG "${(j:,:)present_groups}" "$CLAUDE_USER"
	say "user '$CLAUDE_USER' present; ensured groups: ${(j:,:)present_groups}"
else
	useradd -m -d "$CLAUDE_HOME" -s /bin/bash -G "${(j:,:)present_groups}" "$CLAUDE_USER"
	say "created user '$CLAUDE_USER' (groups: ${(j:,:)present_groups})"
fi

####################
# 2. claude bash XDG env
####################

env_marker='# >>> claude-sandbox XDG env >>>'
read -r -d '' env_block <<'EOF' || true
# >>> claude-sandbox XDG env >>>
export XDG_CONFIG_HOME="$HOME/.local/config"
export XDG_DATA_HOME="$HOME/.local/share"
export CLAUDE_CONFIG_DIR="$XDG_CONFIG_HOME/claude"
export SSH_HOME="$XDG_CONFIG_HOME/ssh"
export PATH="$HOME/.local/bin:$PATH"
# <<< claude-sandbox XDG env <<<
EOF
for rc in .bashrc .bash_profile; do
	f="$CLAUDE_HOME/$rc"
	[[ -f $f ]] || { install -o "$CLAUDE_USER" -g "$CLAUDE_USER" -m 0644 /dev/null "$f"; }
	if ! grep -qF "$env_marker" "$f"; then
		printf '\n%s\n' "$env_block" >> "$f"
		say "seeded XDG env into $f"
	fi
done

####################
# 3-5. /usr/local/bin scripts
####################

tmp=$(mktemp -d) || die "mktemp failed"
trap 'rm -rf "$tmp"' EXIT

# --- claude-run ---
cat > "$tmp/claude-run" <<EOF
#!/usr/bin/env bash
# Launch Claude Code as the \`${CLAUDE_USER}\` user with its XDG environment.
# Invoked via: sudo -u ${CLAUDE_USER} /usr/local/bin/claude-run [args]
# cwd is inherited from the caller (sudo does not reset it).
export HOME=${CLAUDE_HOME}
export XDG_CONFIG_HOME="\$HOME/.local/config"
export XDG_DATA_HOME="\$HOME/.local/share"
export CLAUDE_CONFIG_DIR="\$XDG_CONFIG_HOME/claude"
export SSH_HOME="\$XDG_CONFIG_HOME/ssh"
export PATH="\$HOME/.local/bin:\$PATH"
exec claude "\$@"
EOF

# --- dctl (STACKS path substituted in) ---
cat > "$tmp/dctl" <<'DCTL_EOF'
#!/usr/bin/env bash
# dctl — constrained Docker control for the restricted automation user.
#
# Invoked only via sudo. The Docker CLI is a root-equivalent API, so this
# wrapper — not a sudo wildcard — is what prevents escalation. It allowlists
# containers, verbs and (per container) the commands that may be exec'd, and
# strips the destructive flags (-v on rm, arbitrary -f/-v on compose) that
# would otherwise mean host root. Root-owned, mode 0755.
#   validate after edits:  bash -n /usr/local/bin/dctl
set -euo pipefail

DOCKER=/usr/bin/docker
STACKS=__CLAUDE_STACKS__

# Always-protected names that are sensitive but do NOT mount the socket
# directly (so the dynamic is_socket_or_priv check below would miss them).
# Socket-mounting / privileged containers are protected generically at runtime,
# so they need not be listed here by name.
DENY_MANAGE=(crowdsec)

# Containers whose exec is limited to specific commands (no shell).
DB_CONTAINERS=(romm-db joplin-db immich_postgres immich_redis)
DB_CMDS=(mariadb mysql mysqldump mariadb-dump psql pg_dump pg_dumpall redis-cli)

die() { echo "dctl: $*" >&2; exit 1; }
in_list() { local n=$1; shift; local x; for x in "$@"; do [[ $x == "$n" ]] && return 0; done; return 1; }
log() { logger -t dctl -- "user=${SUDO_USER:-?} $*"; }
valid_name() { [[ $1 =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]+$ ]] || die "invalid name: $1"; }
exists()     { $DOCKER inspect "$1" >/dev/null 2>&1 || die "no such container: $1"; }

# True if container mounts the docker socket or runs privileged.
is_socket_or_priv() {
	local c=$1
	$DOCKER inspect -f '{{range .Mounts}}{{println .Source}}{{end}}' "$c" 2>/dev/null | grep -q 'docker\.sock' && return 0
	[[ $($DOCKER inspect -f '{{.HostConfig.Privileged}}' "$c" 2>/dev/null) == true ]] && return 0
	return 1
}

usage() {
	cat >&2 <<'EOF'
usage:
	dctl restart|start|stop <container>
	dctl rm [-f] <container>              # -v is never allowed (volumes preserved)
	dctl exec <container> <cmd> [args...] # cmd allowlisted per container
	dctl compose <stack> up [-d] | down | restart|start|stop|ps|logs|config|pull [svc...]
EOF
	exit 2
}

[[ $# -ge 1 ]] || usage
verb=$1; shift

case "$verb" in
	restart|start|stop)
		[[ $# -eq 1 ]] || usage
		c=$1; valid_name "$c"; exists "$c"
		in_list "$c" "${DENY_MANAGE[@]}" && die "$c is protected: $verb refused"
		is_socket_or_priv "$c" && die "$c mounts the docker socket or is privileged: $verb refused (use the raw 'sudo docker $verb' lifecycle grant if truly needed)"
		log "$verb $c"; exec $DOCKER "$verb" "$c" ;;
	rm)
		f=()
		while [[ ${1:-} == -* ]]; do
			case "$1" in
				-f|--force) f+=(--force) ;;
				-v|--volume|--volumes) die "rm -v/--volumes is never allowed (would delete data)" ;;
				*) die "unsupported rm flag: $1" ;;
			esac; shift
		done
		[[ $# -eq 1 ]] || usage
		c=$1; valid_name "$c"; exists "$c"
		in_list "$c" "${DENY_MANAGE[@]}" && die "$c is protected: rm refused"
		is_socket_or_priv "$c" && die "$c mounts the docker socket or is privileged: rm refused"
		log "rm ${f[*]:-} $c"; exec $DOCKER rm "${f[@]}" "$c" ;;
	exec)
		[[ $# -ge 2 ]] || usage
		c=$1; shift; valid_name "$c"; exists "$c"; cmd=$1
		if [[ $c == crowdsec ]]; then
			[[ $cmd == cscli ]] || die "crowdsec exec is restricted to: cscli"
		elif in_list "$c" "${DB_CONTAINERS[@]}"; then
			in_list "$cmd" "${DB_CMDS[@]}" || die "$c exec is restricted to: ${DB_CMDS[*]}"
		else
			is_socket_or_priv "$c" && die "$c mounts the docker socket or is privileged: exec refused"
		fi
		log "exec $c -- $*"; exec $DOCKER exec "$c" "$@" ;;
	compose)
		[[ $# -ge 2 ]] || usage
		stack=$1; shift; valid_name "$stack"
		dir="$STACKS/$stack"; file=""
		for cand in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
			[[ -f "$dir/$cand" ]] && { file="$dir/$cand"; break; }
		done
		[[ -n $file ]] || die "no on-disk compose file for stack '$stack' (it may be Portainer-managed)"
		sub=$1; shift
		case "$sub" in
			up)
				for a in "$@"; do [[ $a == -d || $a == --detach ]] || die "compose up allows only -d"; done
				log "compose $stack up $*"; exec $DOCKER compose -f "$file" up "$@" ;;
			down)
				[[ $# -eq 0 ]] || die "compose down takes no extra args (volumes are never removed)"
				log "compose $stack down"; exec $DOCKER compose -f "$file" down ;;
			restart|start|stop|ps|logs|config|pull)
				for a in "$@"; do [[ $a == -* ]] && die "compose $sub: flags not allowed, service names only"; valid_name "$a"; done
				log "compose $stack $sub $*"; exec $DOCKER compose -f "$file" "$sub" "$@" ;;
			*) die "unsupported compose subcommand: $sub" ;;
		esac ;;
	*) usage ;;
esac
DCTL_EOF
sed -i "s#__CLAUDE_STACKS__#${CLAUDE_STACKS}#" "$tmp/dctl"

# --- claude-ctx ---
cat > "$tmp/claude-ctx" <<CTX_EOF
#!/usr/bin/env bash
# claude-ctx — emits the running user's privilege profile for Claude Code's
# SessionStart hook, so each session knows what it can and cannot do.
u=\$(id -un)
if [[ \$u == ${CLAUDE_USER} ]]; then
	cat <<'EOF'
Running as the RESTRICTED automation user.
- sudo: read-only diagnostic allowlist (/etc/sudoers.d/99-claude) + non-escalating container lifecycle (restart/start/stop). NOT in the docker group.
- For escalating docker ops use the dctl wrapper: \`sudo dctl restart|start|stop|rm|exec|compose ...\`
	Protected (refused for exec/rm): any container mounting the docker socket or running privileged, plus crowdsec (its exec is cscli-only).
	rm never deletes volumes; compose only acts on on-disk stacks under the project tree.
- Mutating raw docker/systemctl will fail with "a password is required" — expected; use dctl or a read-only subcommand.
EOF
else
	echo "Running as '\$u' (not the restricted automation user): you likely have broader privileges. For least-privilege Docker ops, launch Claude Code via 'sudo -u ${CLAUDE_USER} claude-run'."
fi
CTX_EOF

for s in claude-run dctl claude-ctx; do
	bash -n "$tmp/$s" || die "$s failed syntax check"
	install -o root -g root -m 0755 "$tmp/$s" "/usr/local/bin/$s"
done
say "installed /usr/local/bin/{claude-run,dctl,claude-ctx}"

####################
# 6. sudoers policies
####################

cat > "$tmp/10-claude-run" <<EOF
# Let the launching account start Claude Code AS the \`${CLAUDE_USER}\` user, no
# password. Runas restricted to ${CLAUDE_USER} (never root); command restricted
# to the root-owned wrapper. Keep TERM/COLORTERM so the TUI renders correctly.
Defaults!/usr/local/bin/claude-run env_keep += "TERM COLORTERM"
${CLAUDE_LAUNCHER} ALL=(${CLAUDE_USER}) NOPASSWD: /usr/local/bin/claude-run, /usr/local/bin/claude-run *
EOF

cat > "$tmp/99-claude" <<EOF
# Restricted NOPASSWD allowlist for the \`${CLAUDE_USER}\` automation user.
# Read-only / diagnostic commands + non-escalating container lifecycle, plus
# the dctl wrapper for escalating verbs. No raw mutating docker.
# Validate after edits:  visudo -cf /etc/sudoers.d/99-claude

Defaults!CLAUDE_SYSTEMD env_delete += "PAGER LESS LESSOPEN LESSCLOSE LV LV_OPTS"

# --- Docker (read-only) ---
Cmnd_Alias CLAUDE_DOCKER = \\
	/usr/bin/docker ps, /usr/bin/docker ps *, \\
	/usr/bin/docker logs *, \\
	/usr/bin/docker inspect *, \\
	/usr/bin/docker stats --no-stream, /usr/bin/docker stats --no-stream *, \\
	/usr/bin/docker images, /usr/bin/docker images *, \\
	/usr/bin/docker version, /usr/bin/docker version *, \\
	/usr/bin/docker info, /usr/bin/docker info *, \\
	/usr/bin/docker top *, /usr/bin/docker port *, /usr/bin/docker diff *, \\
	/usr/bin/docker network ls, /usr/bin/docker network ls *, \\
	/usr/bin/docker network inspect *, \\
	/usr/bin/docker volume ls, /usr/bin/docker volume ls *, \\
	/usr/bin/docker volume inspect *, \\
	/usr/bin/docker compose ls, /usr/bin/docker compose ls *, \\
	/usr/bin/docker compose ps, /usr/bin/docker compose ps *, \\
	/usr/bin/docker compose logs *, \\
	/usr/bin/docker compose config, /usr/bin/docker compose config *

# --- systemd (read-only) ---
Cmnd_Alias CLAUDE_SYSTEMD = \\
	/usr/bin/systemctl status, /usr/bin/systemctl status *, \\
	/usr/bin/systemctl list-units, /usr/bin/systemctl list-units *, \\
	/usr/bin/systemctl list-unit-files, /usr/bin/systemctl list-unit-files *, \\
	/usr/bin/systemctl list-timers, /usr/bin/systemctl list-timers *, \\
	/usr/bin/systemctl list-sockets, /usr/bin/systemctl list-sockets *, \\
	/usr/bin/systemctl is-active *, /usr/bin/systemctl is-enabled *, \\
	/usr/bin/systemctl is-failed *, /usr/bin/systemctl show *, \\
	/usr/bin/systemctl cat *, \\
	/usr/bin/journalctl, /usr/bin/journalctl *

# --- Firewall / network (read-only) ---
Cmnd_Alias CLAUDE_FIREWALL = \\
	/usr/bin/nft list *, \\
	/usr/bin/ufw status, /usr/bin/ufw status *, \\
	/usr/bin/iptables -L, /usr/bin/iptables -L *, \\
	/usr/bin/iptables -S, /usr/bin/iptables -S *, \\
	/usr/bin/iptables -n -L *, /usr/bin/iptables -t * -L *, /usr/bin/iptables -t * -S *, \\
	/usr/bin/ip6tables -L, /usr/bin/ip6tables -L *, \\
	/usr/bin/ip6tables -S, /usr/bin/ip6tables -S *, \\
	/usr/bin/ip6tables -n -L *, /usr/bin/ip6tables -t * -L *, /usr/bin/ip6tables -t * -S *

# --- Disk / hardware (read-only) ---
Cmnd_Alias CLAUDE_DISK = \\
	/usr/bin/fdisk -l, /usr/bin/fdisk -l *, \\
	/usr/bin/lsblk, /usr/bin/lsblk *, \\
	/usr/bin/btrfs filesystem show, /usr/bin/btrfs filesystem show *, \\
	/usr/bin/btrfs filesystem usage *, /usr/bin/btrfs filesystem df *, \\
	/usr/bin/btrfs subvolume list *, /usr/bin/btrfs device stats *, \\
	/usr/bin/dmesg, /usr/bin/dmesg *

# --- Container lifecycle (non-escalating: cannot mount/escape) ---
Cmnd_Alias CLAUDE_LIFECYCLE = \\
	/usr/bin/docker restart *, /usr/bin/docker start *, /usr/bin/docker stop *, \\
	/usr/bin/docker compose restart *, /usr/bin/docker compose start *, \\
	/usr/bin/docker compose stop *

# --- Constrained Docker control wrapper (escalating verbs, arg-validated) ---
Cmnd_Alias CLAUDE_DCTL = /usr/local/bin/dctl, /usr/local/bin/dctl *

${CLAUDE_USER} ALL=(root) NOPASSWD: CLAUDE_DOCKER, CLAUDE_SYSTEMD, CLAUDE_FIREWALL, CLAUDE_DISK, CLAUDE_LIFECYCLE, CLAUDE_DCTL
EOF

for s in 10-claude-run 99-claude; do
	visudo -cf "$tmp/$s" >/dev/null || die "$s failed visudo validation"
	install -o root -g root -m 0440 "$tmp/$s" "/etc/sudoers.d/$s"
done
say "installed /etc/sudoers.d/{10-claude-run,99-claude} (validated)"

####################
# 7. SessionStart hook (best-effort; only if a config dir already exists)
####################

ccfg="$CLAUDE_HOME/.local/config/claude"
if [[ -d $ccfg ]]; then
	say "hint: add the SessionStart hook to $ccfg/settings.json:"
	say '      "hooks": { "SessionStart": [ { "hooks": [ { "type": "command", "command": "/usr/local/bin/claude-ctx" } ] } ] }'
fi

say "done. Launch Claude Code as the restricted user with: sudo -u ${CLAUDE_USER} claude-run"
