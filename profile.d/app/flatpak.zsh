#######################################
### Flatpak
#######################################

if command-has flatpak; then

alias flatpak-remotes="flatpak remotes --columns=priority,options | sort | awk '{print \$NF}'"

### Flatpak environment variables
typeset -Ag FLATPAK_ENV=(
	[USER_APPDATA]="$HOME/.var/app"
	[SYSTEM_DIR]="/var/lib/flatpak"
)

# Set Flatpak environment variables depending on available remotes
for flatpak_remote in $(flatpak-remotes); do
	if [[ "$flatpak_remote" == user ]]; then
		FLATPAK_ENV[USER_DIR]="${XDG_DATA_HOME}/flatpak"
		FLATPAK_ENV[USER_INSTALL]="${FLATPAK_ENV[USER_DIR]}/app"
	elif [[ "$flatpak_remote" == system ]]; then
		FLATPAK_ENV[SYSTEM_INSTALL]="${FLATPAK_ENV[SYSTEM_DIR]}/app"
	fi
done


# Update all Flatpak apps from all installations
function flatpak-update {
	# Fetch all remotes, sorted by priority
	set -- $(flatpak-remotes)
	if (( ! $# )); then
		print_fn -e "No remotes found"
		return 1
	fi

	# Iterate through all installations
	local -a args
	while (( $# )); do
		args=()
		if [[ "$1" =~ (system|user) ]]; then
			args=(--$1)
		elif [[ -f "/etc/flatpak/installations.d/$1" ]]; then
			args=(--installation=$1)
		fi
		flatpak ${args} update -y
		shift
	done
}

fi
