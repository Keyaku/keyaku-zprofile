# Set machine identifiers (Linux, WSL, etc.)

export LIST_machines=()

function whatami {
	local -r usage=(
		"Usage: $(get_funcname) [OPTION...] COMMAND..."
		"\t[-h|--help] : Print this help message"
		"\t[-o|--or] : Logical OR operator. Default behavior. Checks if any of the commands are installed."
		"\t[-a|--and] : Logical AND operator. Checks if all of the commands are installed."
	)

	## Setup func opts
	local f_help f_verbose f_quiet logical=or # default
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{o,-or}=logical \
		{a,-and}=logical \
		|| return 1

	## Help/usage message
	if [[ "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	if (( ! ${#LIST_machines} )); then
		local tmpname

		# Checking by OSTYPE
		if [[ -n "${OSTYPE}" ]]; then
			case "${OSTYPE}" in
			solaris*)        tmpname="Solaris" ;;
			darwin*)         tmpname="macOS" ;;
			*android)        tmpname="Android" ;;
			linux*)          tmpname="Linux" ;;
			bsd*)            tmpname="BSD" ;;
			msys* | cygwin*) tmpname="Windows" ;;
			*microsoft*)     tmpname="WSL" ;;
			*)               tmpname="${OSTYPE}" ;;
			esac
			LIST_machines+=("${tmpname}")
		fi

		# Checking by uname
		tmpname="$(uname -s)"
		(( ${LIST_machines[(i)$tmpname]} <= ${#LIST_machines})) || LIST_machines+=("${tmpname}")
		set +x
		# [[ " ${LIST_machines} " =~ " ${tmpname} " ]] || LIST_machines+=("${tmpname}")

		# Checking by lsb_release
		if (( ${+commands[lsb_release]} )); then
			tmpname="$(lsb_release -si)"
			(( ${LIST_machines[(i)$tmpname]} <= ${#LIST_machines})) || LIST_machines+=("${tmpname}")
		fi

		# Checking from /etc/os-release
		if [[ -f /etc/os-release ]]; then
			tmpname="$(awk -F= '/^ID=/ {print $2}' /etc/os-release)"
			(( ${LIST_machines[(i)$tmpname]} <= ${#LIST_machines})) || LIST_machines+=("${(C)tmpname}")
		fi

		# Checking if RPi
		if \grep -Eq "BCM(283(5|6|7)|270(8|9)|2711)" /proc/cpuinfo; then
			tmpname=pi
			(( ${LIST_machines[(i)$tmpname]} <= ${#LIST_machines})) || LIST_machines+=("${tmpname}")
		fi
	fi

	if (( $# )); then
		local sorted=(${(uoz)@:l})
		local machines=(${(uo)LIST_machines:l})
		local mutual_excl=(${(@)sorted:|machines})

		if [[ "$logical" =~ a(nd)? ]]; then
			# if subtraction is empty, then all elements are present
			(( ! $#mutual_excl ))
		elif [[ "$logical" =~ o(r)? ]]; then
			[[ " ${LIST_machines:l} " =~ " (${sorted:gs/ /|}) " ]]
		fi

		return $?
	fi

	echo ${LIST_machines}
}

