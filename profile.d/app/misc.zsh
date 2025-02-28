#######################################
# Backup systems
#######################################
if command-has borg; then

BORG_SCRIPT="$(whereis borg-backup.sh | awk '{ print $2 }')"

if [[ -f "$BORG_SCRIPT" ]]; then
	alias borg-backup="$BORG_SCRIPT"
	alias borg-backup-edit="vim borg-backup"
fi

unset BORG_SCRIPT

fi


#######################################
# GNUPG
#######################################
function gpg-fix-perms {
	local homedir=${1:-$GNUPGHOME}
	if [[ ! -d "$homedir" ]]; then
		print_fn -e "Unable to fix permissions due to invalid path: '$homedir'"
		return 1
	fi
	find "$homedir" -type f -exec chmod 600 {} \; # Set 600 for files
	find "$homedir" -type d -exec chmod 700 {} \; # Set 700 for directories
}
