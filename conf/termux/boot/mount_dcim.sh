#!/data/data/com.termux/files/usr/bin/env zsh

readonly SCRIPT_DIR="${0:P:h}"
readonly SCRIPT_NAME="${0:P:t}"

# Mount package required
if ! command -v mount &>/dev/null; then
	pkg install -y mount-utils
fi

# Check if directory is mounted already
if mount | \grep -q "[D]CIM"; then
	echo "$SCRIPT_NAME: DCIM is already mounted"
	exit 0
fi

# This script requires su or rish
if command -v sudo &>/dev/null; then
	SUDO=(su)
elif command -v rish &>/dev/null; then
	RISH=(rish -c)
	SUDO=(/system/bin/su)
else
	echo "$SCRIPT_NAME: No root alternative found. Either this device was not rooted, or Termux has no root access."
	exit 1
fi
SUDO+=(-M -c)

# Mount Pictures/DCIM to DCIM to allow cloud services synchronization
readonly PICTURES_DCIM_DIR=$(echo "$HOME"/storage/shared/Pictures/DCIM(:A))
readonly DCIM_DIR=$(echo "$HOME"/storage/shared/DCIM(:A))

${RISH:-$SUDO} "${RISH:+$SUDO }mount -R ${PICTURES_DCIM_DIR} ${DCIM_DIR}"
