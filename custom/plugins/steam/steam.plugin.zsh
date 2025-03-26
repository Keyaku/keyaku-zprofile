(( ${(v)#commands[(I)steam|com.valvesoftware.Steam]} )) || return

### Setting main variables for Steam paths
function steam-set-paths {
	# Default Steam paths
	typeset -Al steam_paths=(
		[STEAM_HOME]=".steam"
		[STEAM_LIBRARY]=".local/share/Steam"
	)

	### Set paths from array
	local env_var env_path
	for env_var env_path in ${(kv)steam_paths}; do
		if [[ -z "${(P)env_var}" || ! -d "${(P)env_var}" ]]; then
			: ${(P)env_var::="$HOME/$env_path"}

			# Check if flatpak (only if default is not available)
			if [[ ! -d "${(P)env_var}" ]]; then
				(( ${+commands[com.valvesoftware.Steam]} )) && : ${(P)env_var::="$HOME/.var/app/com.valvesoftware.Steam/$env_path"}
			fi

			# Force search Steam home in case it was not found (for custom setups)
			if [[ "$env_var" == "STEAM_HOME" && ! -d "${(P)env_var}" ]]; then
				STEAM_HOME="$(find "$HOME" -maxdepth 6 -type d -name ".steam" -not -regex '.*\.?cache.*' -print -quit)"
			fi

			# Export variable or unset it depending on its validity
			[[ -d "${(P)env_var}" ]] && export "${env_var}" || unset "${env_var}"
		fi
	done

	### Check which variables were not set
	for env_var env_path in ${(kv)steam_paths}; do
		if (( ${+commands[steam]} )) && ! env | \grep -qw "$env_var" && [[ -z "${(P)env_var}" || ! -d "${(P)env_var}" ]]; then
			print_fn -e "Could not set '$env_var' environment variable"
		fi
	done
}

# Locate app_id from name
function steam-app-id {
	local library="${STEAM_LIBRARY:-"${XDG_DATA_HOME}"/Steam}"
	if [[ -z "$STEAM_LIBRARY" ]]; then
		print_fn -e "STEAM_LIBRARY environment variable not set. Assuming default: ${XDG_DATA_HOME}/Steam"
	fi

	if (( ! $# )); then
		print_fn -e "Missing App name(s)"
		return 1
	fi

	local retval=0
	while (( $# )); do
		\grep -iElw "$1" ${library}/steamapps/appmanifest_*.acf | sed -E 's|.+?appmanifest_||;s|\.acf||' | \grep .
		((retval += $?))
		shift
	done

	return $retval
}

# Locate SteamLibrary containing app_id
function steam-app-library {
	local retval=0

	local library="${STEAM_LIBRARY:-"${XDG_DATA_HOME}"/Steam}"
	[[ -z "$STEAM_LIBRARY" ]] && {
		print_fn -e "STEAM_LIBRARY environment variable not set. Assuming default: ${XDG_DATA_HOME}/Steam"
	}

	if (( ! $# )); then
		print_fn -e "Missing App ID(s)"
		return 1
	fi

	local app_id
	while (( $# )); do
		if is_int "$1"; then
			app_id="$1"
		else
			app_id=$(steam-app-id "$1") || return 2
		fi

		local app_path=$(
		awk -v app_id="$app_id" '
			/^[[:space:]]*"[0-9]+"$/ {
				in_block = 1;
				block = $0;
				next;
			}
			in_block {
				block = block "\n" $0;
				if ($0 ~ /^\s*}/) {
					in_block = 0;
					if (block ~ "\""app_id"\"") {
						match(block, /"path"\s+"([^"]+)"/, arr);
						print arr[1];
						exit;
					}
				}
			}
			' "${library}/steamapps/libraryfolders.vdf"
		)

		readlink -f "$app_path"
		((retval += $?))
		shift
	done

	return $retval
}

# Locate app compatdata
function steam-app-data {
	local retval=0

	if (( ! $# )); then
		print_fn -e "Missing App ID(s)"
		return 1
	fi

	# Parse arguments
	local app_id
	while (( $# )); do
		if is_int "$1"; then
			app_id="$1"
		else
			app_id=$(steam-app-id "$1") || {
				((retval += $?))
				continue
			}
		fi

		readlink -f "$(steam-app-library "$1")/steamapps/compatdata/${app_id}"
		((retval += $?))
		shift
	done

	return $retval
}

# Fetches Steam app's Proton path
function steam-app-proton {
	local retval=0

	if (( ! $# )); then
		print_fn -e "Missing App ID(s)"
		return 1
	fi

	local app_data proton_version
	while (( $# )) do
		app_data="$(steam-app-data "$1")" || {
			((retval += $?))
			continue
		}

		## Check for Proton version from prefix files
		# Check from config file
		if [[ -f "${app_data}/config_info" ]]; then
			proton_version="$(sed -En '2s,/(files|dist)/.*,,p' "${app_data}/config_info")"
		fi

		# Print Proton version, or error if not found
		if [[ -z "$proton_version" ]]; then
			print_fn -e "Couldn't determine Proton version for '$1'"
			((retval++))
			continue
		fi

		echo "$proton_version"
		shift
	done

	return $retval
}

### Flatpak version
if (( ${+commands[com.valvesoftware.Steam]} )) && (( ! ${(v)#commands[(I)steam|steam-native]})); then
	alias steam='flatpak run com.valvesoftware.Steam'
fi
