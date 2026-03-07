(( ${+commands[flatpak]} )) || return

# Checks if given argument is an installed Flatpak package
function flatpak-has {
	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...]"
		"\t[-h|--help] : Print this help message"
		"\t[-v] / [-q] : Increase / Decrease verbosity"
		"\t[-i|--ignore-case] : Sets case-sensitivity to none"
	)

	## Setup func opts
	local f_help f_verbosity f_icase
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		v+=f_verbosity q+=f_verbosity \
		{i,-ignore-case}=f_icase \
		|| return 1

	## Help/usage message
	if (( ! $# )) && [[ "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	### Arg parsing
	# Verbosity
	local -i verbosity=0
	f_verbosity="${(j::)f_verbosity//-}"
	(( verbosity += (${#f_verbosity//q} - ${#${f_verbosity//v}}) ))

	local -i retval=1

	while (( $# )); do
		local result="$(flatpak list --columns=name,application | awk '{IGNORECASE = '${${f_icase:+1}:-0}'; for(i=1;i<=NF;i++) if (/\<'$1'\>/) { print; break } }')"
		if [[ "$result" ]]; then
			retval=0
			(( 0 < $verbosity )) && echo "$result"
		fi
		shift
	done

	return $retval
}

# Prints Flatpak installations
function flatpak-installations {
	flatpak remotes --columns=priority,name,options | awk '{split($NF, a, ","); print a[1]}' | sort -u -r
}

# Update all Flatpak apps from all installations
function flatpak-update {
	# Fetch all remotes, sorted by priority
	local -a fp_installs=($(flatpak-installations))
	if (( ! ${#fp_installs} )); then
		print_fn -e "No configured installations found"
		return 1
	fi

	# Iterate through all installations
	local fp_i SUDO
	local -a args
	for fp_i in ${fp_installs}; do
		args=()
		SUDO=""
		if [[ "$fp_i" == system || "$fp_i" == user ]]; then
			args=(--$fp_i)
			[[ "$fp_i" == system ]] && SUDO=sudo
		elif [[ -e "/etc/flatpak/installations.d/$fp_i" ]]; then
			args=(--installation=$fp_i)
		fi
		$SUDO flatpak ${args} update -y
	done
}
