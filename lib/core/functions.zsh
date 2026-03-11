# Checker for argument counting in a function
function check_argc {
	local -r usage=(
		"Usage: ${funcstack[1]} numargs minargs [maxargs]"
		"\tnumargs  - (int)                 : \$# of the running function"
		"\tminargs  - (0 <= int)            : minimum number of arguments"
		"\tmaxargs  - (0 <= minargs <= int) : maximum number of arguments. Defaults to ARG_MAX"
	)

	(( 2 <= $# && $# <= 3 )) || {
		print_fn -e "Invalid number of arguments."
		>&2 print -l $usage
		return 1
	}

	# Check if arguments are valid, meaning they're all positive integers
	[[ $1 == <-> && $2 == <-> && ${3:-0} == <-> ]] || {
		print_fn -e "Invalid arguments."
		>&2 print -l $usage
		return 1
	}

	# $1 - minimum number of args
	# $2 - maximum number of args
	# $3 - arg count
	(( $+_ARGC_ARG_MAX )) || typeset -gir _ARGC_ARG_MAX=$(getconf ARG_MAX 2>/dev/null || echo 255)
	local -i argc=$1 minargs=$2 maxargs=${3:-$_ARGC_ARG_MAX}

	# Check if args of this function are correct
	(( 0 <= $minargs && $minargs <= $maxargs )) || {
		>&2 print -l $usage
		return 1
	}

	# Check if the number of arguments is correct
	(( $minargs <= $argc && $argc <= $maxargs )) || {
		print_fn -ec "Argument mismatch: [$minargs-${maxargs//$_ARGC_ARG_MAX/no_limit}] required, $argc given."
		return 1
	}
}

# Get function name relative to current function. Accepts int to reach higher levels if necessary
function get_funcname {
	local -i idx=2
	# Test if argument is an integer and within bounds. Silently drops last frame since it's this function.
	if [[ $1 == <-> ]] && (( 0 < $1 <= ($#funcstack - $idx + 1) )); then
		idx=$((idx + $1))
	fi

	if [[ -n "${funcstack[$idx]}" ]]; then
		echo "${funcstack[$idx]}"
	fi
}

# Function that checks if current execution is being sourced
function is_sourced {
	if [[ "$ZSH_VERSION" ]]; then
		case $ZSH_EVAL_CONTEXT in *:file:*) return 0;; esac
	else  # Add additional POSIX-compatible shell names here, if needed.
		case ${0##*/} in dash|-dash|bash|-bash|ksh|-ksh|sh|-sh) return 0;; esac
	fi

	return 1  # NOT sourced.
}

# Function that checks if current file is being sourced by one of the main zsh profiles
function is_sourced_by {
	setopt extendedglob

	local -i retval=0
	local -i argc=$#
	local zpatterns

	if [[ -z "$ZDOTDIR" || ! -d "$ZDOTDIR" ]]; then
		print_fn -e "ZDOTDIR is not set or does not exist."
		return 1
	elif ! [[ "${funcstack[-1]:h}" =~ "^${ZDOTDIR}" ]]; then
		print_fn -e "ZDOTDIR is not set to a valid directory."
		return 1
	fi

	# Specifiy zprofiles if arguments were given
	if (( $argc )); then
		local arg
		for arg; do
			if test "$ZDOTDIR"/{,.}"${arg:t}"(-.N); then
				zpatterns="${zpatterns:+$zpatterns|}${arg:t}"
			fi
		done

		[[ -n "$zpatterns" && "${funcstack[-1]:t}" =~ "^\.?("${zpatterns}")$" ]]
		retval=$?
	fi

	# If no argument given, print the zprofile
	if (( ! $retval && ! $argc )); then
		print "${funcstack[-1]:t}"
	fi

	return $retval
}

# Function to print the callstack
function _print_callstack {
	(( ${+fg} )) || { autoload -Uz colors && colors; }

	local color="$1"
	local -i is_printing=0
	local -i count idx_stack idx_trace

	local -r can_skip="^(print_\w+|check_argc)$"

	for ((count=1, idx_stack=2, idx_trace=1; idx_stack <= ${#funcstack}; idx_stack++, idx_trace++)); do
		local src=(${(s[:])funcfiletrace[$idx_trace]})
		local caller="${funcstack[$idx_stack]}"

		# Only begin printing after certain conditions were met
		if (( ! $is_printing )); then
			# If caller is one of the skippable functions, skip it
			[[ "$caller" =~ "$can_skip" ]] && continue
			# If callstack contains single function, skip it
			(( ${#funcstack} < $idx_stack+$count )) && break

			# Conditions met; print header
			>&2 printf "%s\n" "Call stack:"
			is_printing=1
		fi

		>&2 printf "\t%d. ${fg_bold[$color]}%s${reset_color} > %s:%d\n" $count "$caller" "${src[1]:t}" ${src[2]}
		(( count++ ))
	done
}

# Base function to print text formatted as "func:lineno: fmt [args]"
function print_fn {
	(( ${+fg} )) || { autoload -Uz colors && colors; }

	# If caller is one of the skippable functions, skip it
	local -r can_skip="^(print_\w+|check_argc)$"

	# Color names for use in fg_bold/fg_no_bold lookups
	local -A lvl_color=(
		[s]="green"    # success
		[e]="red"      # error
		[w]="yellow"   # warning
		[i]="cyan"     # info
		[d]="magenta"  # debug
	)

	## Setup func opts
	local f_help f_level f_callstack f_timestamp f_noheader
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{c,-callstack}=f_callstack \
		{T,-timestamp}=f_timestamp \
		{n,-no-header}=f_noheader \
		{s,-success}=f_level \
		{e,-error}=f_level \
		{w,-warn}=f_level \
		{i,-info}=f_level \
		{d,-debug}=f_level \
		|| return 1

	# Get the first char from the very first f_level argument (any other is discarded)
	f_level=${${f_level[1]//-/}[1]}
	if [[ "${f_callstack}" ]]; then
		[[ -z "$f_level" ]] && f_level=e
	fi

	## Help/usage message
	if ( (( ! $# )) && [[ -z "$f_callstack" ]] ) || [[ -z "$f_level" ]] || [[ "$f_help" ]]; then
		local -a usage=(
			"Usage: ${funcstack[1]} LEVEL [OPTION...] FMT [ARGS...]"
			"\t[-h|--help] : Print this help message"
			"\t[-c|--callstack] : Print the callstack"
			"\t[-T|--timestamp] : Prepend timestamp to the message based on current locale"
			"\t[-n|--no-header] : Omits the 'file:function:line' header from the message"
			"\tLEVEL : One of the following levels:"
			"\t\t-s|--success : ${fg_bold[$lvl_color[s]]}${lvl_color[s]}${reset_color} ${fg_no_bold[$lvl_color[s]]}color${reset_color}, suited for success messages"
			"\t\t-e|--error : ${fg_bold[$lvl_color[e]]}${lvl_color[e]}${reset_color} ${fg_no_bold[$lvl_color[e]]}color${reset_color}, suited for errors"
			"\t\t-w|--warn : ${fg_bold[$lvl_color[w]]}${lvl_color[w]}${reset_color} ${fg_no_bold[$lvl_color[w]]}color${reset_color}, suited for warnings"
			"\t\t-i|--info : ${fg_bold[$lvl_color[i]]}${lvl_color[i]}${reset_color} ${fg_no_bold[$lvl_color[i]]}color${reset_color}, suited for information"
			"\t\t-d|--debug : ${fg_bold[$lvl_color[d]]}${lvl_color[d]}${reset_color} ${fg_no_bold[$lvl_color[d]]}color${reset_color}, suited for debug"
		)

		[[ -z "$f_level" ]] && echo "Missing level argument"
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	# Set color based on level
	local p_color="${lvl_color[$f_level]}"

	# Prepare header => [timestamp]:function:lineno
	local header
	if [[ -z "$f_noheader" ]]; then
		local -i idx=1
		if (( ${#funcstack} <= 1 )); then
			idx=0
			f_level="e"
			unset f_callstack
			set -- "should not be called directly"
		fi

		# Avoid getting other print functions
		while [[ "${funcstack[$idx+1]}" =~ "$can_skip" ]] && (( ${#funcstack} > $idx+1 )); do
			(( idx++ ))
		done

		local src=(${(s[:])funcfiletrace[$idx]})
		local fn_name="${funcstack[$idx+1]}"
		local fn_file="${src[1]:t}"
		local -i fn_line=${src[2]}
		local fn_fullname="${fn_name}"

		if [[ "$fn_name" == "$fn_file" ]]; then
			fn_fullname="$fn_file"
		elif [[ "$fn_file" ]]; then
			fn_fullname="$fn_file:$fn_name"
		fi

		# If fn_file is empty, this function is being called directly, so there's no line
		[[ -z "$fn_file" ]] && unset fn_line

		# Add timestamp if requested
		local -a timestamp
		if [[ "$f_timestamp" ]]; then
			timestamp[2]="${fg_no_bold[$p_color]}$(date +'%c'):${reset_color}"
			timestamp[1]=${#timestamp[2]}+1
		fi

		printf -v header "${timestamp:+%-*s}${fg_bold[$p_color]}%s${fg_no_bold[$p_color]}:${fn_line:+"%d:"}${reset_color}" ${timestamp} "$fn_fullname" $fn_line
	fi

	local message
	printf -v message "$1" ${@:2}

	# Print message via stderr as well
	>&2 printf "${header:+%s }${fg_no_bold[$p_color]}%s${reset_color}" "$header" "$message"

	if [[ "$f_callstack" ]]; then
		[[ "$message" ]] && printf "\n"
		_print_callstack $p_color
	fi
	printf "\n"
	(( $idx ))
}
