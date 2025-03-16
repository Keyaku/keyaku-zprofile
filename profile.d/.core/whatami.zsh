# Set machine identifiers (Linux, WSL, etc.)
typeset -agxU WHATAMI_LIST=()

# Cache file location. Remove this file
WHATAMI_CACHE_FILE="${ZSH_CACHE_HOME:-${XDG_CACHE_HOME:-$HOME/.local/cache}}/whatami_cache"

function whatami {
	local -r usage="Usage: ${funcstack[1]} [DISTRO...]"

	if (( ${@[(I)-*|--*]} )); then
		if (( ${@[(I)-h|--help]} )); then
			>&2 echo "$usage"
			return 0
		else
			print_fn -e "Unknown option: ${(v)@[(I)-*|--*]}"
		fi
	fi

	# Compile list of possible identifiers for this machine
	if (( ! ${#WHATAMI_LIST} )); then
		# Checking by OSTYPE - fast check first
		if [[ "${OSTYPE}" ]]; then
			case "${OSTYPE}" in
			solaris*)        WHATAMI_LIST+=("Solaris") ;;
			darwin*)         WHATAMI_LIST+=("macOS") ;;
			*android)        WHATAMI_LIST+=("Android") ;;
			linux*)          WHATAMI_LIST+=("Linux") ;;
			bsd*)            WHATAMI_LIST+=("BSD") ;;
			msys* | cygwin*) WHATAMI_LIST+=("Windows") ;;
			*microsoft*)     WHATAMI_LIST+=("WSL") ;;
			*)               WHATAMI_LIST+=("${OSTYPE}") ;;
			esac
		fi

		# Only run uname if needed
		if (( ! ${#WHATAMI_LIST} )); then
			WHATAMI_LIST+=("$(uname -s)")
		fi

		# Distribution detection - only if Linux
		if (( ${+WHATAMI_LIST[(r)Linux]} )); then
			if [[ -f /etc/os-release ]]; then
				# Faster than lsb_release
				local distro=$(sed -n 's/^ID=//p' /etc/os-release)
				[[ "$distro" ]] && WHATAMI_LIST+=("${(C)distro}")
			elif (( ${+commands[lsb_release]} )); then
				# Fallback to lsb_release
				WHATAMI_LIST+=("$(lsb_release -si)")
			fi

			# Raspberry Pi check - use simple grep with limited pattern
			if [[ -f /proc/cpuinfo ]] && \grep -q "BCM2" /proc/cpuinfo; then
				WHATAMI_LIST+=("pi")
			fi
		fi

		# Save to cache file
		if (( ${#WHATAMI_LIST} )); then
			[[ -d "${WHATAMI_CACHE_FILE:h}" ]] || mkdir -p "${WHATAMI_CACHE_FILE:h}"
			echo "${WHATAMI_LIST}" > "$WHATAMI_CACHE_FILE"
		fi
	fi

	if (( $# )); then
		(( ${+WHATAMI_LIST[(I)(${(uj:|:)@:l})]} ))
		return $?
	fi

	echo ${WHATAMI_LIST}
}

# Load if cache file exists
if [[ -f "$WHATAMI_CACHE_FILE" ]]; then
	WHATAMI_LIST=($(cat "$WHATAMI_CACHE_FILE"))
fi
