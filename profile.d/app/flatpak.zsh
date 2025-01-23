if command-has flatpak; then

### Generic

# Update all Flatpak apps from all installations
function flatpak-update {
	# Fetch all remotes, sorted by priority
	set -- $(flatpak remotes --columns=priority,options | sort | awk '{print $NF}')

	# Iterate through all installations
	local args
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
