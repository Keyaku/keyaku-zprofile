### Aliases to get default settings
alias xdg-get-default-browser='xdg-settings get default-web-browser'

### Migrate from one directory to another using envvars
# TODO: Implement missing functionality
function xdg-migrate {
	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...] SRC_PATH DST_PATH"
		"\t-h, --help : Displays this message"
		"\t-d, --dry-run : Do not execute anything; just print"
		# "\t-e, --env ENV_VAR : Pick environment variable. May help finding respective directories"
		# "\t-s, --symbolic : Create a symbolic link instead of moving the directory"
	)

	## Setup func opts
	local -i invalid_args=0
	local f_help f_dryrun f_env
	zparseopts -D -E -K -- \
		{h,-help}=f_help \
		{d,-dry-run}=f_dryrun \
		|| return 1


	## Check positional arguments
	local -A reqs=(
		[src]=1
		[dst]=1
	)
	if [[ -z "${f_help}" ]]; then
		if (( $# != ${(k)#reqs} )); then
			print_fn -e "${(k)#reqs} arguments required, $# given"
			return 1
		elif [[ ! -e "$1" ]]; then
			print_fn -e "'$1': path not found or valid"
			return 1
		else
			reqs[src]="$1"
			reqs[dst]="$2"
		fi
	fi

	## Parse arguments
	if [[ "$f_dryrun" ]]; then
		f_dryrun="echo"
		echo "Dry-run mode enabled"
	fi

	# TODO: check envvar against XDG table

	## Help/usage message
	if [[ "${f_help}" ]] || (( ${invalid_args} )); then
		>&2 print -l $usage
		[[ "${f_help}" ]]; return $?
	fi

	## If source is a directory
	if [[ -d "${reqs[src]}" ]]; then
		echo "Migrating ${reqs[src]} to ${reqs[dst]}..."
		if [[ -d "${reqs[dst]}" ]]; then
			$f_dryrun rsync -Prazq "${reqs[src]}"/ "${reqs[dst]}" && rm -r "${reqs[src]}"
		else
			$f_dryrun mv "${reqs[src]}" "${reqs[dst]}"
		fi
	## If source is a file
	elif [[ -f "${reqs[src]}" ]]; then
		echo "Moving ${reqs[src]} to ${reqs[dst]}..."
		[[ -d "${reqs[dst]}" ]] || mkdir -p "${reqs[dst]}"
		$f_dryrun mv "${reqs[src]}" "${reqs[dst]}"/.
	else
		print_fn -e "Something went wrong; '${reqs[src]}' not a valid file or directory"
		return 128
	fi

	return 0
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

	printf "%s %s\n" "Number of dotfiles: $dotcount" "$([[ "$f_all" ]] && printf "(including .local)")"

	if (( $dotcount )); then
		## If simple mode, use printf's array unroll
		if [[ "$f_simple" ]]; then
			printf " - %s\n" "${(@)dotfiles}"
		# Otherwise, print detailed info
		else
			declare -A dotfiles_info
			local dotfile
			for dotfile in ${(@)dotfiles}; do
				printf " - \033[1m\033[3m%-10s\033[0m : %s\n" "$dotfile" "$(file -b "$HOME/$dotfile")"
			done
		fi
	fi

}
