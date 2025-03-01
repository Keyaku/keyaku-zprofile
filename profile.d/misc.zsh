#######################################
# Backup systems
#######################################
if command-has borg; then

BORG_SCRIPT="$(whereis borg-backup.sh | awk '{ print $2 }')"

if [[ -f "$BORG_SCRIPT" ]]; then
	alias borg-backup="$BORG_SCRIPT"
	alias borg-backup-edit="vim $BORG_SCRIPT"
fi

unset BORG_SCRIPT

fi

