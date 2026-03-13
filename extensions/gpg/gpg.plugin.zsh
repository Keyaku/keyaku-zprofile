(( ${+commands[gpg]} || ${+commands[gpgconf]} )) || return

# Fix permissions of gpg homedir
function gpg-fix-perms {
	local homedir=${1:-$GNUPGHOME}
	if [[ ! -d "$homedir" ]]; then
		print_fn -e "Unable to fix permissions due to invalid path: '$homedir'"
		return 1
	fi
	chmod 600 "$homedir"/{**,.*/**}/*(-.) # Set 600 for files
	chmod 700 "$homedir"/{**,.*/**}/(-/)  # Set 700 for directories
}
