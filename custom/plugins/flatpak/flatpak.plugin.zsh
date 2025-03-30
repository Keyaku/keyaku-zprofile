(( ${+commands[flatpak]} )) || return

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
	local -a fp_remotes=($(flatpak-remotes))
	if (( ! ${#fp_remotes} )); then
		print_fn -e "No remotes found"
		return 1
	fi

	# Iterate through all installations
	local fp_remote SUDO
	local -a args
	for fp_remote in ${fp_remotes}; do
		args=()
		SUDO=""
		if [[ "$fp_remote" == system || "$fp_remote" == user ]]; then
			args=(--$fp_remote)
			[[ "$fp_remote" == system ]] && SUDO=sudo
		elif [[ -e "/etc/flatpak/installations.d/$fp_remote" ]]; then
			args=(--installation=$fp_remote)
		fi
		$SUDO flatpak ${args} update -y
	done
}
