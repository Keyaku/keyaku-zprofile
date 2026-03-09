##############################################
### String functions
##############################################

# Check if string $1 contains all substrings from arguments (case-sensitive)
function str_contains {
	local haystack="$1"
	shift

	local arg
	for arg; do
		[[ "$haystack" == *"$arg"* ]] || return 1
	done
}

# Check if string $1 starts with substring $2
function str_starts_with {
	[[ -n "$2" && "$1" == "$2"* ]]
}

# Joins array of strings with delimiter
function str_join {
	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...] ARRAY"
		"\t[-h|--help] : Print this help message"
		"\t-d|--delim|--delimiter EXPRESSION : Sets the delimiter to EXPRESSION. Default: ' '"
	)

	## Setup parseopts
	local f_help delim=" "
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{d,-delim,-delimiter}:=delim \
		|| return $?

	## Help/usage message
	if [[ -n "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	check_argc $# 1 || return 1

	## Print result
	local d="${delim[-1]}"
	local f="${1-}"
	printf %s "$f" "${@/#/$d}"
}

# Count number of occurrences of any substring in string $1
function count_occurrences {
	check_argc $# 2 || return 1

	# $1  - Haystack
	# $2+ - Needle(s)
	local haystack="$1"
	local stripped
	shift

	local arg
	for arg; do
		if [[ -z "$arg" ]]; then
			print 0
		else
			local stripped="${haystack//$arg/}"
			print $(( (${#haystack} - ${#stripped}) / ${#arg} ))
		fi
	done
}
