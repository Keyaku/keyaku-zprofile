#!/usr/bin/env zsh

# Borg backup runner.
#
# Runs as root (via sudo): a system backup needs to read /etc, /root, and
# /var/lib paths the invoking user can't see. Per-host settings live in
# borg-config.override.json (gitignored via '*.override.*') and are merged
# on top of borg-config.json at runtime — edit the override, not the base.

emulate -L zsh
setopt pipefail extendedglob

### CONSTANTS

# Standardized $0 handling
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#zero-handling
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

readonly THIS=${0:t}
readonly THIS_NAME=${THIS:r}

# Shared script libs (bootstrap pulls in lib/core + lib/interactive).
#
# Never trust an inherited ZDOTDIR: under `sudo` (no -E) or systemd it points at
# root's tree (or is unset), not ours. Find the repo root by walking up from the
# script's own resolved location ($0 is the /usr/local/bin symlink; :A follows
# it) to the nearest ancestor holding .zshenv — which is, by definition, ZDOTDIR.
# Depth-independent, so moving the script within the repo can't break it, and
# unlike `git rev-parse` it adds no runtime dependency on an actual checkout.
ZDOTDIR=$(
	d=${0:A:h}
	while [[ $d != / && ! -e $d/.zshenv ]]; do d=${d:h}; done
	print -r -- $d
)
if ! typeset -f _zsh_source_dir >/dev/null; then
	# Outside an interactive/login shell (sudo without -E, systemd) the env
	# framework was never loaded. Pull it in via .zshenv — but zstages/env
	# re-derives ZDOTDIR from root's $XDG_CONFIG_HOME as a side effect, so stash
	# our value and restore it before bootstrap consumes it.
	typeset _zdotdir=$ZDOTDIR
	source "${ZDOTDIR}/.zshenv"
	ZDOTDIR=$_zdotdir
	unset _zdotdir
fi
source "${ZDOTDIR}/lib/script/bootstrap.zsh"

command-has -v borg || exit 1
if command-has jaq; then
	readonly JQ=jaq
elif command-has jq; then
	readonly JQ=jq
else
	print_fn -e "Neither jaq nor jq is installed."
	exit 1
fi

readonly -a usage=(
	"Usage: ${THIS} [OPTION...]"
	"\t[-h|--help]                Print this help message"
	"\t[-n|--dry-run]             Pass --dry-run to borg create; skip prune/compact/sync"
	"\t[-p|--passphrase[=VAL]]    Use VAL as repo passphrase; if omitted, read from stdin"
	""
	"PASSPHRASE RESOLUTION (in order)"
	"\t1. -p/--passphrase flag (explicit value or stdin prompt)"
	"\t2. systemd credential at \$CREDENTIALS_DIRECTORY/borg-passphrase"
	"\t3. /etc/borg/passphrase"
)

### MAIN

# Wrapped in a function so print_fn (which inspects funcstack) works — it
# refuses to run at top-level script scope.
function main {
	# --- Option parsing ---
	local f_help f_dry f_pass
	zparseopts -D -F -K -- \
		{h,-help}=f_help     \
		{n,-dry-run}=f_dry   \
		{p,-passphrase}::=f_pass \
		|| exit 1

	if [[ -n "$f_help" ]]; then
		>&2 print -l $usage
		exit 0
	fi

	if (( $# )); then
		print_fn -e "Unexpected positional argument: %s" "$1"
		>&2 print -l $usage
		exit 1
	fi

	local -ir DRY_RUN=${#f_dry}

	# --- Privilege check ---
	if [[ -z "$SUDO_USER" ]] || (( UID != 0 )); then
		print_fn -e "This script must be run as sudo."
		exit 1
	fi

	readonly BORG_USER="${SUDO_USER:-$USER}"
	readonly BORG_USER_HOME="$(getent passwd "$BORG_USER" | cut -d: -f6)"

	# Resolve against the target user's config dir, never root's. Honor an explicit
	# XDG_CONFIG_HOME only when it lives under their home — under bare sudo/systemd
	# it points at /root and would misdirect us to a nonexistent config.
	local _xdg="${XDG_CONFIG_HOME:-$BORG_USER_HOME/.local/config}"
	[[ "$_xdg" == "$BORG_USER_HOME"/* ]] || _xdg="$BORG_USER_HOME/.local/config"
	readonly BORG_CONFIG_DIR="$_xdg/borg"
	readonly BORG_CONFIG_FILE="$BORG_CONFIG_DIR/borg-config.json"
	readonly BORG_EXCLUDES_DIR="$BORG_CONFIG_DIR/excludes"

	if [[ ! -d "$BORG_CONFIG_DIR" ]]; then
		print_fn -e "Directory not found: %s" "$BORG_CONFIG_DIR"
		exit 1
	elif [[ ! -f "$BORG_CONFIG_FILE" ]]; then
		print_fn -e "%s not found in %s" "${BORG_CONFIG_FILE:t}" "$BORG_CONFIG_DIR"
		exit 1
	fi
	export BORG_CONFIG_DIR

	# --- Passphrase ---
	if (( ${#f_pass} )); then
		local pass="${f_pass[-1]}"
		if [[ -z "$pass" ]]; then
			read -rs "pass?Enter borg passphrase: "
			print  # newline after hidden input
		fi
		export BORG_PASSPHRASE="$pass"
		unset pass
	elif [[ -n "$CREDENTIALS_DIRECTORY" && -f "$CREDENTIALS_DIRECTORY/borg-passphrase" ]]; then
		export BORG_PASSCOMMAND="cat $CREDENTIALS_DIRECTORY/borg-passphrase"
	elif [[ -f /etc/borg/passphrase ]]; then
		export BORG_PASSCOMMAND="cat /etc/borg/passphrase"
	else
		print_fn -e "No passphrase found; either run via systemd with a loaded credential, create /etc/borg/passphrase, or use -p/--passphrase."
		exit 1
	fi

	# --- Merge override config if present ---
	# Objects are merged recursively (nested keys are patched, not replaced).
	# Arrays are replaced wholesale — override backup_paths means specifying all of them.
	readonly BORG_OVERRIDE_FILE="$BORG_CONFIG_DIR/borg-config.override.json"
	local _merged_config=""
	if [[ -f "$BORG_OVERRIDE_FILE" ]]; then
		# Stream both files through stdin: jaq's -s only slurps the first file
		# argument, so pass them concatenated instead of as multiple args.
		_merged_config=$(cat "$BORG_CONFIG_FILE" "$BORG_OVERRIDE_FILE" | $JQ -s '.[0] * .[1]') || {
			print_fn -e "Failed to parse or merge %s" "${BORG_OVERRIDE_FILE:t}"
			exit 1
		}
		print_fn -i "Override config applied: %s" "${BORG_OVERRIDE_FILE:t}"
	fi

	function _cfg {
		if [[ -n "$_merged_config" ]]; then
			$JQ -r "$1" <<< "$_merged_config"
		else
			$JQ -r "$1" "$BORG_CONFIG_FILE"
		fi
	}

	# --- Read configuration ---
	local BORG_REPO=$(_cfg '.repo')
	local COMPRESSION=$(_cfg '.compression')
	local EXCLUDE_ALL=$(_cfg '.exclude_lists.all')
	local LOG_DIR=$(_cfg '.log_dir')
	[[ -z "$LOG_DIR" || "$LOG_DIR" == "null" ]] && LOG_DIR="/var/log/borg"
	export BORG_REPO

	# --- Build --exclude-from arguments ---
	local -a exclude_args=()
	if [[ "$EXCLUDE_ALL" == "true" ]]; then
		local lst
		for lst in "$BORG_EXCLUDES_DIR"/*.lst(.N); do
			exclude_args+=("--exclude-from=$lst")
		done
	else
		local exclude_fname exclude_fpath
		while IFS= read -r exclude_fname; do
			exclude_fpath="$BORG_EXCLUDES_DIR/${exclude_fname}.lst"
			if [[ -f "$exclude_fpath" ]]; then
				exclude_args+=("--exclude-from=$exclude_fpath")
			else
				print_fn -w "Exclude list not found, skipping: %s" "$exclude_fpath"
			fi
		done < <(_cfg '.exclude_lists.files[]')
	fi

	# --- Build --exclude pattern arguments ---
	local -a exclude_pattern_args=()
	local pattern
	while IFS= read -r pattern; do
		exclude_pattern_args+=("--exclude=$pattern")
	done < <(_cfg '.exclude_patterns // [] | .[]')

	# --- Build backup paths ---
	# (@f) splits on newlines into a proper zsh array
	local -a backup_paths=("${(@f)$(_cfg '.backup_paths[]')}")

	# --- rclone configuration ---
	local RCLONE_ENABLED=$(_cfg '.rclone.enabled')
	local RCLONE_CONFIG="${XDG_CONFIG_HOME:-$BORG_USER_HOME/.local/config}/rclone/rclone.conf"
	local RCLONE_NAME=$(_cfg '.rclone.name')
	local RCLONE_REMOTE_PATH=$(_cfg '.rclone.remote_path')

	# --- Ensure required directories exist ---
	mkdir -p "$LOG_DIR" "$BORG_CONFIG_DIR/backup_lists"

	# --- Export Flatpak app list before backgrounding ---
	# The resulting file lives inside BORG_CONFIG_DIR, so it's captured by the backup.
	if command-has flatpak; then
		if flatpak list --app --columns=application,branch,origin \
			> "$BORG_CONFIG_DIR/backup_lists/flatpak-apps.lst"; then
			print_fn -i "Flatpak app list saved: %s" "$BORG_CONFIG_DIR/backup_lists/flatpak-apps.lst"
		else
			print_fn -w "Failed to export Flatpak app list."
		fi
	fi

	# --- Export Homebrew formula list before backgrounding ---
	# Check well-known Linux Homebrew location first, then fall back to PATH.
	local _brew_bin=/home/linuxbrew/.linuxbrew/bin/brew
	[[ ! -x "$_brew_bin" ]] && _brew_bin=$(command -v brew 2>/dev/null || true)
	if [[ -x "$_brew_bin" ]]; then
		if sudo -u "$BORG_USER" "$_brew_bin" list --formula \
			> "$BORG_CONFIG_DIR/backup_lists/brew-formulae.lst"; then
			print_fn -i "Brew formula list saved: %s" "$BORG_CONFIG_DIR/backup_lists/brew-formulae.lst"
		else
			print_fn -w "Failed to export Brew formula list."
		fi
	fi
	unset _brew_bin

	# ---------------------------------------------------------------------------
	# _run_backup: everything from here runs in the background, fully detached.
	# Both stdout and stderr are redirected to the dated log at launch (see bottom).
	# print_fn writes to stderr — fine, both streams land in the same log file.
	# ---------------------------------------------------------------------------
	function _info {
		# Plain printf so timestamps in the log are unadorned by print_fn's prefixes.
		printf "\n%s %s\n\n" "$(now)" "$*"
	}

	function _run_backup {
		local -a dry_run_flag=()
		(( DRY_RUN )) && dry_run_flag=("--dry-run")

		if (( DRY_RUN )); then
			_info "Starting backup (dry run)"
		else
			_info "Starting backup"
		fi

		borg create                          \
			--verbose                        \
			--filter AME                     \
			--list                           \
			--stats                          \
			--show-rc                        \
			--compression "$COMPRESSION"     \
			--exclude-caches                 \
			"${(@)exclude_args}"             \
			"${(@)exclude_pattern_args}"     \
			"${(@)dry_run_flag}"             \
			::'{hostname}-{now}'             \
			"${(@)backup_paths}"
		local -i backup_exit=$?

		if (( DRY_RUN )); then
			_info "Dry run complete — no archive was created, no pruning or sync performed"
			return $backup_exit
		fi

		_info "Pruning repository"
		borg prune                         \
			--list                         \
			--glob-archives '{hostname}-*' \
			--show-rc                      \
			--keep-daily   7               \
			--keep-weekly  4               \
			--keep-monthly 6
		local -i prune_exit=$?

		_info "Compacting repository"
		borg compact
		local -i compact_exit=$?

		# --- rclone sync ---
		local -i rclone_exit=0
		if [[ "$RCLONE_ENABLED" == "true" ]]; then
			if [[ ! -f "$RCLONE_CONFIG" ]]; then
				_info "rclone sync is enabled, but '$RCLONE_CONFIG' not found."
				rclone_exit=1
			else
				local -a rclone_args=(-L -v)
				_info "Synchronizing with the cloud (rclone => $RCLONE_NAME)"
				rclone --config="$RCLONE_CONFIG" sync "${(@)rclone_args}" "$BORG_REPO" "$RCLONE_NAME:$RCLONE_REMOTE_PATH"
				rclone_exit=$?
			fi
		fi

		# --- Final exit code (highest wins) ---
		local -i global_exit=$(( backup_exit  > prune_exit  ? backup_exit  : prune_exit  ))
		global_exit=$(( compact_exit > global_exit ? compact_exit : global_exit ))
		global_exit=$(( rclone_exit  > global_exit ? rclone_exit  : global_exit ))

		case $global_exit in
			0) _info "Backup, Prune, Compact and Sync finished successfully" ;;
			1) _info "Backup, Prune, Compact and/or Sync finished with warnings" ;;
			*) _info "Backup, Prune, Compact and/or Sync finished with errors" ;;
		esac

		return $global_exit
	}

	trap 'print "$(now) Backup interrupted"; exit 2' INT TERM

	# --- Launch: foreground for systemd and dry runs, detached otherwise ---
	if [[ -n "$INVOCATION_ID" ]] || (( DRY_RUN )); then
		_run_backup
	else
		local DATED_LOG="$LOG_DIR/backup-$(date +%Y-%m-%d_%H-%M).log"

		# Delete logs older than 15 days
		find "$LOG_DIR" -name 'backup-*.log' -mtime +15 -delete

		_run_backup >> "$DATED_LOG" 2>&1 &!
		print_fn -s "Backup started in background (PID $!)."
		print "Follow progress with: tail -f $DATED_LOG"
	fi
	trap - INT TERM
}

main "$@"
