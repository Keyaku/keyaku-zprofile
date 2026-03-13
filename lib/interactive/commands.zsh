# ============================================================================
# Command-related helpers
# ============================================================================

# Checks argument list for valid commands.
# Can make use of operators AND and OR.
function command-has {
	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...] COMMAND..."
		"\t[-h|--help] : Print this help message"
		"\t[-v] / [-q] : Increase / Decrease verbosity"
		"\t[-o|--or] : Logical OR operator. Default behavior. Checks if any of the commands are valid."
		"\t[-a|--and] : Logical AND operator. Checks if all of the commands are valid."
	)

	## Setup func opts
	## FIXME: add flag for ignoring if command is alias
	local f_help f_verbosity f_exit
	local -a logical=(-o) # default
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		v+=f_verbosity q+=f_verbosity \
		{o,-or}=logical \
		{a,-and}=logical \
		|| return 1

	## Help/usage message
	if (( ! $# )) || [[ "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	## Arg parsing
	if (( ${logical[(I)-o]} && ${logical[(I)-a]} )); then
		print_fn -e "Flags -o and -a are mutually exclusive"
		return 1
	fi

	# Verbosity
	local -i verbosity=0
	f_verbosity="${(j::)f_verbosity//-}"
	(( verbosity += (${#f_verbosity//q} - ${#${f_verbosity//v}}) ))
	# Logical OR / AND
	logical=${logical##*-}

	# # function logic
	local args="${(j:|:)@}"

	## Print invalid commands
	if (( $verbosity )); then
		local -aU valid=(${commands[(I)($args)]} ${functions[(I)($args)]} ${aliases[(I)($args)]})
		local -aU invalid=(${@:|valid})
		if (( ${#invalid} )); then
			print_fn -e "Not found:"
			>&2 printf '%s\n' "${(j:, :)invalid}"
		fi
	fi

	# Fastest process to check for commands
	# Count total matches across commands, functions and aliases
	local results=$(( ${(v)#commands[(I)($args)]} + ${#functions[(I)($args)]} + ${#aliases[(I)($args)]} ))
	{ [[ "${logical}" == (a|and) ]] && (( $# == $results )) } ||
	{ [[ "${logical}" == (o|or) ]] && (( $results )) }
}

# Obtains the path to the program behind the command or alias
function command-path {
	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION]... COMMAND..."
	)
	local help_msg=(
		${usage}
		"Obtains the path to the underlying program of a command or recursive alias."
		""
		"Possible options:"
		"\t-h, --help : Print this help message"
		"\t-l, --line : Print results line by line"
	)

	## Setup func opts
	local f_help f_line
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{l,-line}=f_line \
		|| return 1

	## Help/usage message
	if [[ -z "$f_help" ]] && (( ! $# )); then
		>&2 print -l $usage
		return 1
	elif [[ "$f_help" ]]; then
		>&2 print -l $help_msg
		return 0
	fi

	# This pattern implies that the path is absolute (i.e. begins with /)
	local result=(${(f)"$(whence -pa ${(u)@} 2>/dev/null)"})
	[[ "${result}" ]] && {
		if [[ "$f_line" ]]; then
			print -l $result
		else
			print ${(Q)result}
		fi
	}
}
