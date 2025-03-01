(( ${(v)+commands[(I)gpg|gpgconf]} )) || return

export GNUPGHOME="${GNUPGHOME:-$XDG_DATA_HOME/gnupg}"

function gpg-fix-perms {
	local homedir=${1:-$GNUPGHOME}
	if [[ ! -d "$homedir" ]]; then
		print_fn -e "Unable to fix permissions due to invalid path: '$homedir'"
		return 1
	fi
	chmod 600 "$GNUPGHOME"/{**,.*/**}/*(-.) # Set 600 for files
	chmod 700 "$GNUPGHOME"/{**,.*/**}/(-/)  # Set 700 for directories
}
