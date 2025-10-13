### Aliases to get default settings
alias xdg-get-default-browser='xdg-settings get default-web-browser'

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
