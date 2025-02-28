(( ${+commands[flatpak]} )) || return

function flatpak-has {
	local -r usage=(
		"Usage: $(get_funcname) [OPTION...]"
		"\t[-h|--help] : Print this help message"
		"\t[-v] / [-q] : Increase / Decrease verbosity"
		"\t[-i|--ignore-case] : Sets case-sensitivity to none"
	)

	## Setup func opts
	local f_help f_verbose f_quiet f_icase
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		v+=f_verbose q+=f_quiet \
		{i,-ignore-case}=f_icase \
		|| return 1

	## Help/usage message
	if (( ! $# )) && [[ "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	# Setup parameters
	local verbosity=0
	(( verbosity += ($#f_verbose - $#f_quiet) ))
	local icase=$(( ${#f_icase} ? 1 : 0 ))

	local retval=1

	while (( $# )); do
		local result="$(flatpak list --columns=name,application | awk '{IGNORECASE = '${icase}'; for(i=1;i<=NF;i++) if (/\<'$1'\>/) { print; break } }')"
		if [[ "$result" ]]; then
			retval=0
			(( 0 < $verbosity )) && echo "$result"
		fi
		shift
	done

	return $retval
}

function flatpak-remotes {
	flatpak remotes --columns=priority,options | sort | awk '{print $NF}'
}

### Flatpak environment variables
typeset -Ag FLATPAK_ENV=(
	[USER_APPDATA]="$HOME/.var/app"
	[SYSTEM_DIR]="/var/lib/flatpak"
)

# Set Flatpak environment variables depending on available remotes
flatpak-remotes | while read -r; do
	if [[ "$REPLY" == user ]]; then
		FLATPAK_ENV[USER_DIR]="${XDG_DATA_HOME}/flatpak"
		FLATPAK_ENV[USER_INSTALL]="${FLATPAK_ENV[USER_DIR]}/app"
	elif [[ "$REPLY" == system ]]; then
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
