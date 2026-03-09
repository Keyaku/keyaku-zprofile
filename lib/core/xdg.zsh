### Aliases to get default settings
alias xdg-get-default-browser='xdg-settings get default-web-browser'

### Migrate from one directory to another using envvars
# TODO: Implement missing functionality
function xdg-migrate {
	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...] SRC_PATH DST_PATH"
		"\t-h, --help : Displays this message"
		"\t-d, --dry-run : Do not execute anything; just print"
		"\t-s, --symbolic : Create a symbolic link instead of migrating"
		# "\t-e, --env ENV_VAR : Pick environment variable. May help finding respective directories"
	)

	## Setup func opts
	local f_help f_dryrun f_sym
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{d,-dry-run}=f_dryrun \
		{s,-symbolic}=f_sym \
		|| return 1


	if [[ -n "$f_help" ]]; then
		>&2 print -l $usage
		return 0
	fi

	## Check positional arguments
	check_argc $# 2 2 || return 1
	[[ -e "$1" ]] || { print_fn -e "'$1': path not found or valid"; return 1; }
	local src="$1" dst="$2"

	## Parse arguments
	if [[ "$f_dryrun" ]]; then
		f_dryrun="echo"
		echo "Dry-run mode enabled"
	fi

	# TODO: check envvar against XDG table

	local -i retval=0
	## If symlink was requested
	if [[ "${f_sym}" ]]; then
		echo "Creating symbolic link from $src to $dst..."
		if [[ -L "$src" ]]; then
			print_fn -e "Path '$src' exists and already is a symbolic link"
			retval=1
		elif [[ -e "$dst" ]]; then
			print_fn -e "Path '$dst' exists. Aborting"
			retval=1
		else
			$f_dryrun ln -s "$src" "$dst"
			retval=$?
		fi
	## If src is a directory
	elif [[ -d "$src" ]]; then
		echo "Migrating $src to $dst..."
		if [[ -d "$dst" ]]; then
			$f_dryrun rsync -Prazq "$src"/ "$dst" && $f_dryrun rm -r "$src"
		else
			$f_dryrun mv "$src" "$dst"
		fi
		retval=$?
	## If src is a file
	elif [[ -f "$src" ]]; then
		echo "Moving $src to $dst..."
		[[ -d "$dst" ]] || mkdir -p "$dst"
		$f_dryrun mv "$src" "$dst"
		retval=$?
	else
		print_fn -e "Something went wrong; '$src' not a valid file or directory"
		retval=128
	fi

	return $retval
}

### Update desktop entries
alias xdg-desktop-update="update-desktop-database $XDG_DATA_HOME/applications"

# Check for dotfiles in HOME
function xdg-home-check {
	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...] FILENAME"
		"\t[-h|--help]"
	)

	## Setup func opts
	local f_help f_simple f_all
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{s,-simple}=f_simple \
		{a,-all}=f_all \
		|| return 1

	## Help/usage message
	if [[ "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	local dotfiles dotcount
	dotfiles=($HOME/.*(:s,$HOME/,,))
	dotcount=${#dotfiles}
	if [[ -z "$f_all" ]]; then
		dotfiles=(${dotfiles:#.local})
		dotcount=${#dotfiles}
	fi

	printf "%s%s\n" "Number of dotfiles: $dotcount" "${f_all:+ (including .local)}"

	if (( $dotcount )); then
		## If simple mode, use printf's array unroll
		if [[ "$f_simple" ]]; then
			printf " - %s\n" "${(@)dotfiles}"
		# Otherwise, print detailed info
		else
			local dotfile
			for dotfile in ${(@)dotfiles}; do
				printf " - \033[1m\033[3m%-10s\033[0m : %s\n" "$dotfile" "$(file -b "$HOME/$dotfile")"
			done
		fi
	fi

}
