if command_has steam com.valvesoftware.Steam; then

### WeMod launcher
WEMOD_HOME="${GIT_HOME:-$HOME/.local/git}/_games/wemod-launcher"
[[ -d "$WEMOD_HOME" ]] && export WEMOD_HOME || unset WEMOD_HOME

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
				command_has com.valvesoftware.Steam && : ${(P)env_var::="$HOME/.var/app/com.valvesoftware.Steam/$env_path"}
			fi

			# Force search Steam home in case it was not found (for custom setups)
			if [[ "$env_var" == "STEAM_HOME" && ! -d "${(P)env_var}" ]]; then
				STEAM_HOME="$(find "$HOME" -maxdepth 4 -type d -name ".steam" -not -regex '.*\.?cache.*' -print -quit)"
			fi

			# Export variable or unset it depending on its validity
			[[ -d "${(P)env_var}" ]] && export "${env_var}" || unset "${env_var}"
		fi
	done

	### Check which variables were not set
	for env_var env_path in ${(kv)steam_paths}; do
		if command_has steam && ! env | \grep -qw "$env_var" && [[ -z "${(P)env_var}" || ! -d "${(P)env_var}" ]]; then
			print_error "Could not set '$env_var' environment variable"
		fi
	done
}
steam-set-paths

# Locate app_id from name
function steam-app-id {

	local library="${STEAM_LIBRARY:-"${XDG_DATA_HOME}"/Steam}"
	[[ -z "$STEAM_LIBRARY" ]] && {
		print_error "STEAM_LIBRARY environment variable not set. Assuming default: ${XDG_DATA_HOME}/Steam"
	}

	(( ! $# )) && {
		print_error "Missing App name(s)"
		return 1
	}

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
		print_error "STEAM_LIBRARY environment variable not set. Assuming default: ${XDG_DATA_HOME}/Steam"
	}

	if (( ! $# )); then
		print_error "Missing App ID(s)"
		return 1
	fi

	local arg app_id
	for arg in $@; do
		if is_int "$arg"; then
			app_id="$arg"
		else
			app_id=$(steam-app-id "$arg") || return 2
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
	done

	return $retval
}

# Locate app compatdata
function steam-app-data {
	local retval=0

	if (( ! $# )); then
		print_error "Missing App ID(s)"
		return 1
	fi

	# Parse arguments
	local arg app_id
	for arg in $@; do
		if is_int "$arg"; then
			app_id="$arg"
		else
			app_id=$(steam-app-id "$arg") || {
				((retval += $?))
				continue
			}
		fi

		readlink -f "$(steam-app-library "$arg")/steamapps/compatdata/${app_id}"
		((retval += $?))
	done

	return $retval
}

# Fetches Steam app's Proton path
function steam-app-proton {
	local retval=0

	if (( ! $# )); then
		print_error "Missing App ID(s)"
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
			print_error "Couldn't determine Proton version for '$1'"
			((retval++))
			continue
		fi

		echo "$proton_version"
		shift
	done

	return $retval
}

### Flatpak version


fi
