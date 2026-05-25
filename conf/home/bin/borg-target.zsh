#!/usr/bin/env zsh

# Borg backup *target* provisioner — the per-host companion to borg-backup.zsh.
#
# Runs as root (via sudo): prepares a btrfs backup target and everything the
# nightly runner needs to use it. All steps are idempotent and the only
# destructive one (--format) is gated behind both the flag and a confirmation:
#
#   1. (optional) wipefs + mkfs.btrfs a device, labelling it.
#   2. Write & enable a per-host systemd .mount unit (these are NOT tracked in
#      the repo — they vary per machine).
#   3. chown the mountpoint to the invoking user; create a root-owned borg/ dir.
#   4. Ensure /etc/borg/passphrase (0400) exists, then derive the systemd-creds
#      encrypted credential the borg-backup.service loads.
#   5. Point borg-config.override.json at <mountpoint>/borg.
#   6. borg init the repo if it isn't already initialized.

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
# Never trust an inherited ZDOTDIR: under `sudo` (no -E) it points at root's
# tree (or is unset), not ours. Find the repo root by walking up from the
# script's own resolved location ($0 is the /usr/local/bin symlink; :A follows
# it) to the nearest ancestor holding .zshenv — which is, by definition, ZDOTDIR.
ZDOTDIR=$(
	d=${0:A:h}
	while [[ $d != / && ! -e $d/.zshenv ]]; do d=${d:h}; done
	print -r -- $d
)
if ! typeset -f _zsh_source_dir >/dev/null; then
	# Outside an interactive/login shell the env framework was never loaded.
	# Pull it in via .zshenv — but zstages/env re-derives ZDOTDIR from root's
	# $XDG_CONFIG_HOME as a side effect, so stash and restore our value.
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

# Default btrfs mount options. Deliberately generic: btrfs autodetects SSD and
# trim, so we don't hardcode ssd/discard (wrong for a spinning external drive).
# nofail keeps a missing/removable target from blocking boot.
readonly DEFAULT_MOUNT_OPTS="noatime,compress=zstd:3,nofail"
readonly CRED_DIR=/etc/credstore.encrypted
readonly CRED_NAME=borg-passphrase

readonly -a usage=(
	"Usage: ${THIS} --label LABEL [OPTION...]"
	"\t[-h|--help]                 Print this help message"
	"\t[-l|--label] LABEL          btrfs filesystem label (required)"
	"\t[-m|--mountpoint] PATH      Mountpoint (default: /mnt/LABEL)"
	"\t[-d|--device] DEV           Block device — required only with --format"
	"\t[-f|--format]               wipefs + mkfs.btrfs DEV (destructive; prompts)"
	"\t[-e|--encryption] MODE      borg init mode (default: repokey-blake2)"
	"\t[-o|--mount-options] OPTS   Override mount options (default: $DEFAULT_MOUNT_OPTS)"
	"\t[--no-init]                 Skip borg init"
	"\t[--no-credential]           Skip deriving the systemd-creds credential"
	""
	"Provisions a btrfs backup target and wires it for borg-backup. Run as sudo."
)

### MAIN

# Wrapped in a function so print_fn (which inspects funcstack) works — it
# refuses to run at top-level script scope.
function main {
	# --- Option parsing ---
	local f_help f_label f_mount f_device f_format f_enc f_mopts f_noinit f_nocred
	zparseopts -D -F -K -- \
		{h,-help}=f_help              \
		{l,-label}:=f_label           \
		{m,-mountpoint}:=f_mount      \
		{d,-device}:=f_device         \
		{f,-format}=f_format          \
		{e,-encryption}:=f_enc        \
		{o,-mount-options}:=f_mopts   \
		-no-init=f_noinit             \
		-no-credential=f_nocred       \
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

	# --- Privilege check ---
	if [[ -z "$SUDO_USER" ]] || (( UID != 0 )); then
		print_fn -e "This script must be run as sudo."
		exit 1
	fi

	# --- Resolve arguments ---
	local LABEL="${f_label[-1]}"
	if [[ -z "$LABEL" ]]; then
		print_fn -e "A filesystem --label is required."
		>&2 print -l $usage
		exit 1
	fi

	local MOUNTPOINT="${f_mount[-1]:-/mnt/$LABEL}"
	local DEVICE="${f_device[-1]}"
	local ENCRYPTION="${f_enc[-1]:-repokey-blake2}"
	local MOUNT_OPTS="${f_mopts[-1]:-$DEFAULT_MOUNT_OPTS}"
	local -ir DO_FORMAT=${#f_format}
	local -ir SKIP_INIT=${#f_noinit}
	local -ir SKIP_CRED=${#f_nocred}

	local BORG_USER="${SUDO_USER:-$USER}"
	local BORG_USER_HOME="$(getent passwd "$BORG_USER" | cut -d: -f6)"

	# Resolve the config dir against the target user's home, never root's. Honor
	# an explicit XDG_CONFIG_HOME only when it lives under their home.
	local _xdg="${XDG_CONFIG_HOME:-$BORG_USER_HOME/.local/config}"
	[[ "$_xdg" == "$BORG_USER_HOME"/* ]] || _xdg="$BORG_USER_HOME/.local/config"
	local BORG_CONFIG_DIR="$_xdg/borg"
	local OVERRIDE_FILE="$BORG_CONFIG_DIR/borg-config.override.json"
	local REPO="$MOUNTPOINT/borg"

	# --- 1. Format (opt-in, destructive) ---
	if (( DO_FORMAT )); then
		if [[ -z "$DEVICE" ]]; then
			print_fn -e "--format requires --device."
			exit 1
		elif [[ ! -b "$DEVICE" ]]; then
			print_fn -e "Not a block device: %s" "$DEVICE"
			exit 1
		fi

		print_fn -w "About to ERASE %s and create a btrfs filesystem labelled '%s'." "$DEVICE" "$LABEL"
		lsblk -o NAME,LABEL,FSTYPE,SIZE,MOUNTPOINT "$DEVICE" 2>/dev/null
		if ! ask -B -d n "Proceed with wiping $DEVICE?"; then
			print_fn -i "Aborted; no changes made."
			exit 0
		fi

		# Unmount anything udisks may have auto-mounted from this device first.
		command-has udisksctl && udisksctl unmount -b "$DEVICE" 2>/dev/null
		wipefs -a "$DEVICE" || { print_fn -e "wipefs failed."; exit 1; }
		mkfs.btrfs -L "$LABEL" "$DEVICE" || { print_fn -e "mkfs.btrfs failed."; exit 1; }
		print_fn -s "Formatted %s as btrfs (label '%s')." "$DEVICE" "$LABEL"
	fi

	# --- 2. systemd .mount unit (per-host, untracked) ---
	command-has systemd-escape || { print_fn -e "systemd-escape not found; is systemd present?"; exit 1; }
	local UNIT_NAME UNIT_PATH
	UNIT_NAME=$(systemd-escape --path --suffix=mount "$MOUNTPOINT")
	UNIT_PATH="/etc/systemd/system/$UNIT_NAME"

	mkdir -p "$MOUNTPOINT"
	cat > "$UNIT_PATH" <<-EOF
		[Unit]
		Description=Mount $LABEL backup target (btrfs)

		[Mount]
		What=LABEL=$LABEL
		Where=$MOUNTPOINT
		Type=btrfs
		Options=$MOUNT_OPTS

		[Install]
		WantedBy=local-fs.target
	EOF
	print_fn -s "Wrote mount unit: %s" "$UNIT_PATH"

	systemctl daemon-reload
	systemctl enable --now "$UNIT_NAME" || { print_fn -e "Failed to enable/start %s" "$UNIT_NAME"; exit 1; }
	if ! findmnt --target "$MOUNTPOINT" >/dev/null; then
		print_fn -e "%s is not mounted after starting the unit." "$MOUNTPOINT"
		exit 1
	fi
	print_fn -s "Mounted: %s" "$MOUNTPOINT"

	# --- 3. Ownership: mountpoint to the user, borg/ kept root-owned ---
	chown "$BORG_USER":"$BORG_USER" "$MOUNTPOINT"
	install -d -m 0755 -o root -g root "$REPO"

	# --- 4. Passphrase + systemd-creds credential ---
	install -d -m 0700 -o root -g root /etc/borg
	if [[ ! -f /etc/borg/passphrase ]]; then
		openssl rand -base64 48 > /etc/borg/passphrase
		chmod 0400 /etc/borg/passphrase
		chown root:root /etc/borg/passphrase
		print_fn -s "Generated borg passphrase: /etc/borg/passphrase"
	else
		print_fn -i "Passphrase already present: /etc/borg/passphrase (kept)"
	fi

	if (( ! SKIP_CRED )); then
		if command-has systemd-creds; then
			install -d -m 0700 -o root -g root "$CRED_DIR"
			local cred_path="$CRED_DIR/$CRED_NAME.cred"
			if [[ -f "$cred_path" ]]; then
				print_fn -i "Encrypted credential already present: %s (kept)" "$cred_path"
			else
				systemd-creds encrypt --name="$CRED_NAME" /etc/borg/passphrase "$cred_path" \
					&& chmod 0400 "$cred_path" \
					&& print_fn -s "Derived encrypted credential: %s" "$cred_path" \
					|| print_fn -w "Failed to derive encrypted credential."
			fi
		else
			print_fn -w "systemd-creds not found; skipping encrypted credential."
		fi
	fi

	# --- 5. Point the override config at this repo ---
	mkdir -p "$BORG_CONFIG_DIR"
	local merged
	if [[ -f "$OVERRIDE_FILE" ]]; then
		merged=$($JQ --arg r "$REPO" '.repo = $r' "$OVERRIDE_FILE") \
			|| { print_fn -e "Failed to update %s" "${OVERRIDE_FILE:t}"; exit 1; }
	else
		merged=$($JQ -n --arg r "$REPO" '{repo: $r}')
	fi
	print -r -- "$merged" > "$OVERRIDE_FILE"
	chown "$BORG_USER":"$BORG_USER" "$OVERRIDE_FILE"
	print_fn -s "Override repo set to %s in %s" "$REPO" "${OVERRIDE_FILE:t}"

	# --- 6. Initialize the repo ---
	if (( SKIP_INIT )); then
		print_fn -i "Skipping borg init (--no-init)."
	elif [[ -f "$REPO/config" ]]; then
		print_fn -i "Repo already initialized: %s" "$REPO"
	else
		if BORG_PASSCOMMAND="cat /etc/borg/passphrase" borg init --encryption="$ENCRYPTION" "$REPO"; then
			print_fn -s "Initialized repo (%s): %s" "$ENCRYPTION" "$REPO"
		else
			print_fn -e "borg init failed."
			exit 1
		fi
	fi

	print_fn -s "Target ready. Verify with: sudo borg-backup.zsh --dry-run"
}

main "$@"
