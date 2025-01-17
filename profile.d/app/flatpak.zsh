if command_has flatpak; then

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

# Check for the first match of an installed Flatpak application
function flatpak-has {
	local usage=(
		"Usage: $(get_funcname) [OPTION...]"
		"\t[-h|--help]"
		"\t[-i|--ignore-case] : Sets case-sensitivity to none"
		"\t[-v] : Increases verbosity"
		"\t[-q] : Dereases verbosity"
	)

	## Setup zparseopts
	local f_help f_verbose f_quiet f_icase
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		v+=f_verbose \
		q+=f_quiet \
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

fi
