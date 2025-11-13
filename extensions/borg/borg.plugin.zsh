(( ${+commands[borg]} )) || return

# Looks for a user-defined borg script in $PATH, containing the entire procedure for backup
BORG_SCRIPT="$(whereis borg-backup.sh | awk '{ print $2 }')"

if [[ -f "$BORG_SCRIPT" ]]; then
	alias borg-backup="$BORG_SCRIPT"
	alias borg-backup-edit="vim $BORG_SCRIPT"
fi

unset BORG_SCRIPT
