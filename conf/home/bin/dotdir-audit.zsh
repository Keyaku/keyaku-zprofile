#!/usr/bin/env zsh

# HOME dotdir writer-audit (auditd backend).
#
# Discovers which processes create or write the XDG-violating dotdirs we keep as
# symlinks into .local/ (.cache, .config, .pki), so you can catch the rogue
# programs that ignore the XDG spec for them. Uses the kernel audit subsystem
# (auditctl/ausearch) rather than fatrace, because fatrace's fanotify mount
# marks are broken on btrfs subvolumes.
# Must run as root.
#
# Covers every user: each /home/*/.{cache,config,pki} plus /root's, so the audit
# is host-wide, not tied to one account.
#
# WORKFLOW
#   dotdir-audit start    Install audit watches and begin logging.
#   dotdir-audit report   Pretty-print who has hit a watched path (comm/exe/pid).
#   dotdir-audit stop     Remove the watches.
#
#   This is a RECREATION test: it only watches dotdirs that are ABSENT. Remove a
#   dotdir's symlink first, then `start` drops an empty, correctly-owned
#   placeholder there and watches it. A rogue program that ignores XDG_* will
#   repopulate the literal ~/.<name>, and the first write into the placeholder
#   logs its comm/exe. When done, rmdir the placeholder and restore the symlink.
#
#   Existing/symlinked dotdirs are deliberately skipped: `-w` on a populated
#   directory compiles to a recursive `-F dir=` rule (auditctl(8) deprecates it
#   for "poor performance") that audits the whole subtree and floods auditd.

emulate -L zsh
setopt pipefail extendedglob

### CONSTANTS

# Standardized $0 handling
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#zero-handling
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

readonly THIS=${0:t}
readonly THIS_NAME=${THIS:r}

# Shared script libs (bootstrap pulls in lib/core + lib/interactive). Never
# trust an inherited ZDOTDIR: under sudo (no -E) or systemd it points at root's
# tree (or is unset). Find the repo root by walking up from the script's own
# resolved location to the nearest ancestor holding .zshenv.
ZDOTDIR=$(
	d=${0:A:h}
	while [[ $d != / && ! -e $d/.zshenv ]]; do d=${d:h}; done
	print -r -- $d
)
if ! typeset -f _zsh_source_dir >/dev/null; then
	typeset _zdotdir=$ZDOTDIR
	source "${ZDOTDIR}/.zshenv"
	ZDOTDIR=$_zdotdir
	unset _zdotdir
fi
source "${ZDOTDIR}/lib/script/bootstrap.zsh"

# Dotdir basenames to watch, and the audit key tying our rules together.
readonly -a WATCH_NAMES=(cache config pki)
readonly AUDIT_KEY=dotdir_audit

readonly -a usage=(
	"Usage: ${THIS} <start|stop|report> [OPTION...]"
	"\tstart    Install auditd watches on every user's dotdirs and start logging"
	"\tstop     Remove the watches this tool installed"
	"\treport [WHEN]   Summarise captured events; WHEN scopes via 'ausearch -ts' (e.g. recent, today, HH:MM:SS)"
	"\t[-h|--help]"
)

### HELPERS

# Emit the set of paths to watch, one per line, and create the placeholders for
# them. For each real login home (uid 0 or >=1000, skipping service dirs like
# /home/linuxbrew) and each watched basename:
#   - absent dotdir  -> mkdir an empty, owner-matched placeholder and watch it.
#     A watch on an empty dir is cheap (fires only on writes into it) yet still
#     records the culprit's comm/exe when a rogue program repopulates ~/.<name>.
#   - existing dotdir (or symlink) -> skip; a recursive `-F dir=` watch on a
#     populated tree floods auditd. Remove the symlink first to test recreation.
function _watch_paths {
	local -a homes
	local line uid hd
	for line in ${(f)"$(getent passwd 2>/dev/null)"}; do
		uid=${${(s.:.)line}[3]}
		hd=${${(s.:.)line}[6]}
		{ (( uid == 0 )) || (( uid >= 1000 )) } && [[ -d "$hd" && "$hd" != / ]] && homes+="$hd"
	done
	homes=(${(u)homes})

	local home name dotdir
	for home in $homes; do
		for name in $WATCH_NAMES; do
			dotdir="$home/.$name"
			# Skip a live XDG symlink (e.g. .cache -> .local/cache): watching it
			# compiles to a recursive dir= rule over the managed target tree and
			# floods auditd. Remove the symlink to test what recreates the path.
			if [[ -L "$dotdir" ]]; then
				print_fn -w "Skipping $dotdir (symlink; remove it to test recreation)."
				continue
			fi
			# Absent: drop an empty, owner-matched placeholder to watch. Already a
			# real dir (our placeholder from a prior run — possibly repopulated by
			# the culprit — or a rogue-created dir): watch it as-is, so a restart
			# keeps catching writers instead of silently dropping the watch.
			if [[ ! -e "$dotdir" ]]; then
				mkdir -p "$dotdir" 2>/dev/null && chown --reference="$home" "$dotdir" 2>/dev/null \
					|| { print_fn -w "Could not create placeholder: $dotdir"; continue }
			fi
			print -r -- "$dotdir"
		done
	done
}

### SUBCOMMANDS

function _do_start {
	command-has auditctl || { print_fn -e "auditctl not found (install the 'audit' package)."; return 1; }
	systemctl is-active --quiet auditd || systemctl start auditd 2>/dev/null

	local p
	local -i n=0
	for p in ${(f)"$(_watch_paths)"}; do
		# -p wa: writes + attribute changes (creation/use). Idempotent-ish:
		# re-adding an identical rule is harmless beyond a kernel warning.
		if auditctl -w "$p" -p wa -k "$AUDIT_KEY" >/dev/null 2>&1; then
			(( n++ ))
		else
			print_fn -w "Could not watch: $p"
		fi
	done
	print_fn -s "Installed $n dotdir watch(es) under key '$AUDIT_KEY'. Read with: $THIS report"
}

function _do_stop {
	command-has auditctl || { print_fn -e "auditctl not found."; return 1; }
	# Remove every rule carrying our key — not just those matching the current
	# dir state — so watches added when a dotdir's existence differed (symlink
	# since restored/removed) don't linger. Parse the live rule list for paths.
	local line p
	local -i n=0
	for line in ${(f)"$(auditctl -l 2>/dev/null)"}; do
		[[ "$line" == *"-k $AUDIT_KEY"* ]] || continue
		p=${${(s: :)line}[2]}   # the path after '-w'
		auditctl -W "$p" -p wa -k "$AUDIT_KEY" >/dev/null 2>&1 && (( n++ ))
	done
	print_fn -s "Removed $n dotdir watch(es)."
}

function _do_report {
	command-has ausearch || { print_fn -e "ausearch not found."; return 1; }

	# Optional time window, passed straight to `ausearch -ts` (e.g. "recent",
	# "today", "boot", "HH:MM:SS", or a date) so a fresh test run isn't drowned
	# in historical events. No args => whole log.
	local -a ts_args
	(( $# )) && ts_args=(-ts "$@")

	# ERE matching the watched literal dotdir paths. `[.]` (not \.) keeps awk's
	# dynamic-regex engine quiet while staying valid ERE; POSIX classes only.
	local -r names="${(j:|:)WATCH_NAMES}"
	local -r pattern="(/home/[^/]+|/root)/[.](${names})(/|\$)"

	# -i interprets numeric fields; events are separated by a `----` line. Pull
	# the timestamp (from msg=audit(<date time>:serial)), the acting process and
	# the touched name= path, keeping only events that hit a watched dotdir.
	# Drop our own auditctl rule-management syscalls — they are not real users.
	ausearch -k "$AUDIT_KEY" $ts_args -i 2>/dev/null | awk -v pat="$pattern" '
		/^----/ { ts=""; comm=""; exe=""; path=""; next }
		# Timestamp lives in msg=audit(<date> <time>:<serial>); the serial is the
		# final colon-group, so capture everything before it (time has colons).
		match($0, /msg=audit\((.+):[0-9]+\)/, m) { if (ts == "") ts = m[1] }
		{
			for (i = 1; i <= NF; i++) {
				if ($i ~ /^comm=/) { comm = substr($i, 6); gsub(/"/, "", comm) }
				if ($i ~ /^exe=/)  { exe  = substr($i, 5); gsub(/"/, "", exe) }
				if ($i ~ /^name=/) { p = substr($i, 6); gsub(/"/, "", p); if (p ~ pat) path = p }
			}
		}
		path != "" && comm != "" && comm != "auditctl" {
			printf "%-22s %-18s %-28s %s\n", ts, comm, exe, path
			path=""
		}
	' | sort -u | { print -r -- "TIME                   PROCESS            EXE                          PATH"; cat; }
}

### MAIN

function main {
	local f_help
	zparseopts -D -F -K -- {h,-help}=f_help || { >&2 print -l $usage; return 1; }
	if [[ -n "$f_help" || $# -eq 0 ]]; then
		>&2 print -l $usage
		[[ -n "$f_help" ]]; return $?
	fi

	(( EUID == 0 )) || { print_fn -e "Must run as root."; return 1; }

	case "$1" in
		start)  _do_start ;;
		stop)   _do_stop ;;
		report) _do_report "${@[2,-1]}" ;;
		*)      print_fn -e "Unknown subcommand: $1"; >&2 print -l $usage; return 1 ;;
	esac
}

main "$@"
