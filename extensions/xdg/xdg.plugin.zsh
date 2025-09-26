### Set & get default browser simplified
function xdg-set-default-browser {
	local LIST_apps=()
	local appinfo appname appid

	# Print caveat when using this function
	if (( ! ${+commands[flatpak]} )); then
		print_fn -e "Error: This function requires flatpak."
		return 1
	elif (( ! $#  )); then
		print_fn -i "Note: This function only works with Flatpak applications."
	# Search the app from arguments
	else
		LIST_apps=($@)
	fi

	# Prompt for app info
	while (( ${#LIST_apps[@]} == 0 )); do
		ask -kp "Write Flatpak app Name or ID:"
		LIST_apps=($(flatpak list --columns=application | \grep -i "$REPLY"))

		# No results found
		if (( 0 == ${#LIST_apps[@]} )); then
			printf "%s:\t'%s'\n" "No results found from given expression" "$REPLY"
		# List available options if more than one have been found
		elif (( 1 < ${#LIST_apps[@]} )); then
			echo "Multiple results found:"
			printf "* %s\n" "${LIST_apps[@]}"
			LIST_apps=()
		fi
	done

	# Set app pparameters
	appinfo="$(flatpak list --columns=name,application | \grep "${LIST_apps}")"
	appname="$(echo "$appinfo" | awk '{print $1}')"
	appid="$(echo "$appinfo" | awk '{print $NF}')"

	if [[ -z "$appid" ]]; then
		print_fn -e "No Flatpak Application ID set. Aborting"
	fi

	echo "Setting $appname (ID: $appid) as the default browser"
	xdg-mime default "${appid}.desktop" x-scheme-handler/https x-scheme-handler/http
	xdg-settings set default-web-browser "${appid}.desktop"
}

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
