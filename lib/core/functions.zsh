# Checker for argument counting in a function
function check_argc {
	set -o err_return

	local -r usage=(
		"Usage: ${funcstack[1]} minargs maxargs numargs"
		"\tminargs  - (0 <= int)            : minimum number of arguments"
		"\tmaxargs  - (0 <= minargs <= int) : maximum number of arguments"
		"\tnumargs  - (int)                 : \$# of the running function"
	)
	local -ir ARG_MAX=$(getconf ARG_MAX)

	# Check if arguments are valid, meaning they're all positive integers
	[[ $* =~ ^([0-9]+[[:space:]]+){2}[0-9]+$ ]] || {
		print_fn -e "Invalid arguments."
		>&2 print -l $usage
		return 1
	}

	# $1 - minimum number of args
	# $2 - maximum number of args
	# $3 - arg count
	local -i minargs=$1 maxargs=$2 argc=$3
	(( 0 == $maxargs )) && maxargs=$ARG_MAX

	# Check if args of this function are correct
	(( 2 <= $# && 0 <= $minargs && $minargs <= $maxargs )) || {
		>&2 print -l $usage
		return 1
	}

	# Check if the number of arguments is correct
	(( $minargs <= $argc && $argc <= $maxargs )) || {
		print_fn -ec "Argument mismatch: [$minargs-${maxargs//$ARG_MAX/no_limit}] required, $argc given."
		return 1
	}
}

# Get function name relative to current function. Accepts int to reach higher levels if necessary
function get_funcname {
	local -i idx=2
	# Test if argument is an integer and within bounds
	if [[ $1 == <-> ]] && (( 0 < $1 <= ($#funcstack - $idx + 1) )); then
		idx=$((idx + $1))
	fi

	if [[ ! -z "${funcstack[$idx]}" ]]; then
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

	local -ra zprofiles=(.zshenv .zprofile .zshrc .zlogin .zlogout)
	local zpatterns
	local -i argc=$#

	# Specifiy zprofiles if arguments were given
	if (( $argc )); then
		while (( $# )); do
			if test "$ZDOTDIR"/{,.}"${1:t}"(-.N); then
				zpatterns="${zpatterns:+$zpatterns|}${1:t}"
			fi
			shift
		done

		if [[ -z "$zpatterns" ]]; then
			# No valid zprofile given
			return 1
		fi
	# Otherwise, check for all zprofiles
	else
		zpatterns="${(j:|:)zprofiles}"
	fi

	[[ "${funcstack[-1]:t}" =~ "^\.?("${zpatterns}")$" ]]
	local retval=$?

	# If no argument given, print the zprofile
	if (( ! $retval && ! $argc )); then
		echo "${funcstack[-1]:t}"
	fi

	return $retval
}

# Function to print the callstack
function _print_callstack {
	local color="$1"
	local -i is_printing=0
	local -i count idx_stack idx_trace

	for ((count=1, idx_stack=2, idx_trace=1; idx_stack <= ${#funcstack}; idx_stack++, idx_trace++)); do
		local src=(${(s[:])funcfiletrace[$idx_trace]})
		local caller="${funcstack[$idx_stack]}"

		# Only begin printing after certain conditions were met
		if (( ! $is_printing )); then
			# If caller is part of the print functions or check_argc, skip it
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
	(( ${+functions[colors]} )) || autoload -Uz colors
	[[ "$LS_COLORS" ]] || colors

	# auxiliary function to print color examples
	function _usage_color_aux {
		echo "Uses ${fg_bold[$1]}$1${reset_color} ${fg_no_bold[$1]}color${reset_color}"
	}

	# If caller is part of the print functions or check_argc, skip it
	local -r can_skip="^(print_\w+|check_argc)$"

	local -A lvl_color=(
		[e]="red"    # error = red
		[w]="yellow" # warning = yellow
		[i]="green"  # info = green
		[d]="white"  # debug = white
	)

	local -r usage=(
		"Usage: ${funcstack[1]} LEVEL [OPTION...] FMT [ARGS...]"
		"\t[-h|--help] : Print this help message"
		"\t[-c|--callstack] : Print the callstack"
		"\t[-T|--timestamp] : Prepend timestamp to the message based on current locale"
		"\tLEVEL : One of the following levels:"
		"\t\t-e|--error : $(_usage_color_aux ${lvl_color[e]}), suited for errors"
		"\t\t-w|--warn[ing] : $(_usage_color_aux ${lvl_color[w]}), suited for warnings"
		"\t\t-i|--info : $(_usage_color_aux ${lvl_color[i]}), suited for information"
		"\t\t-d|--debug : $(_usage_color_aux ${lvl_color[d]}), suited for debug"
	)
	unfunction _usage_color_aux

	## Setup func opts
	local f_help f_level f_callstack f_timestamp
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{c,-callstack}=f_callstack \
		{T,-timestamp}=f_timestamp \
		{e,-error}=f_level \
		{w,-warn{,ing}}=f_level \
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
		[[ -z "$f_level" ]] && echo "Missing level argument"
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	local -i idx=1
	if (( ${#funcstack} <= 1 )); then
		idx=0
		f_level="e"
		unset f_callstack
		set -- "should not be called directly"
	fi

	# Avoid getting other print functions
	while [[ "${funcstack[$idx+1]}" =~ "$can_skip" ]] && (( ${#funcstack} < $idx+1 )); do
		(( idx++ ))
	done

	local src=(${(s[:])funcfiletrace[$idx]})
	local fn_name="$(get_funcname $idx)"
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

	# Set color based on level
	local color="${lvl_color[$f_level]}"

	# Add timestamp if requested
	local -a timestamp
	if [[ "$f_timestamp" ]]; then
		timestamp[2]="${fg_no_bold[$color]}$(date +'%c'):${reset_color}"
		timestamp[1]=${#timestamp[2]}+1
	fi

	# Print message via stderr as well
	local message="$(printf "$1" ${@:2})"
	>&2 printf "${timestamp:+%-*s}${fg_bold[$color]}%s${fg_no_bold[$color]}:${fn_line:+"%d:"}${reset_color} %s" ${timestamp} "$fn_fullname" $fn_line "$message"
	if [[ "$f_callstack" ]]; then
		[[ "$message" ]] && printf "\n"
		_print_callstack $color
	fi
	printf "\n"
	(( $idx ))
}
