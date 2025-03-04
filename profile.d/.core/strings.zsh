##############################################
### String functions
##############################################

# Check if string $1 contains any substring from arguments (case-sensitive)
function str_contains {
	local haystack="$1"
	shift

	(( $# )) && while (( $# )); do
		[[ "$haystack" == *"$1"* ]] || return $?
		shift
	done
}

# Check if string $1 starts with substring $2
function str_starts_with {
	[[ "$1" =~ ^"${2:-[[:space:]]}".* ]]
}

# Joins array of strings with delimiter
function str_join {
	local -r usage=(
		"Usage: $(get_funcname) [OPTION...] ARRAY"
		"\t[-h|--help]"
		"\t-d|--delim|--delimiter EXPRESSION (e.g. -d:)"
	)

	## Setup parseopts
	local f_help delim
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{d,-delim,-delimiter}:=delim \
		|| return $?

	## Help/usage message
	if (( ! $# )) || [[ "$f_help" || -z "${delim}" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	## Print result
	local d="${delim[-1]}"
	local f="${1-}"
	printf %s "$f" "${@/#/$d}"
}

# Count number of occurrences of any substring in string $1
function count_occurrences {
	# $1  - Haystack
	# $2+ - Needle(s)
	local haystack="$1"
	shift

	(( $# )) && while (( $# )); do
		echo "${haystack}" | \grep -Fo "$1" | wc -l
		shift
	done
}
