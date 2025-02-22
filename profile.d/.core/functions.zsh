##############################################
### Base functions
##############################################

### ZSH helpers

# Assign a value to a named variable
function assign {
	check_argc 2 2 $# || return $?
	if [[ ! -v "$1" ]]; then
		print_invalidarg "$1" "Argument is not a variable"
		return 1
	# FIXME: doesn't work with arrays
	elif is_array $1 || is_array $2; then
		print_fn -e "This function does not work with arrays!"
		return 2
	fi

	# Magic ZSH expansion
	: ${(P)1::=${2}}
}

##############################################
### Argument functions
##############################################

# Checker for argument counting in a function
function check_argc {
	local usage=(
		"usage: $(get_funcname) minargs maxargs numargs"
		"\tminargs  - (0 <= int)            : minimum number of arguments"
		"\tmaxargs  - (0 <= minargs <= int) : maximum number of arguments"
		"\tnumargs  - (int)                 : \$# of the running function"
	)

	# $1 - minimum number of args
	# $2 - maximum number of args
	# $3 - arg count
	local retval=0 minargs=${1:-0} maxargs=${2:-0} argc=${3}
	local funcname="$(get_funcname 1)"
	(( 0 == $maxargs )) && maxargs=$(getconf ARG_MAX)

	# Check if args of this function are correct
	(( 2 <= $# && 0 <= $minargs && $minargs <= $maxargs )) || {
		>&2 print -l $usage
		return 1
	}

	# Check if the number of arguments is correct
	(( $minargs <= $argc && $argc <= $maxargs )) || {
		print_fn -e "Argument mismatch: [$minargs-$maxargs] required, $argc given."
		print_callstack
		return 2
	}
}

# Check if argument is an integer
function is_int {
	[[ "$1" =~ ^-?[0-9]+$ ]]
}

# Check if argument is a number
function is_num {
	[[ $1 =~ ^[+-]?[0-9]+([.][0-9]+)?$ ]]
}

# Check if argument is any type of array (including associative/dictionary)
function is_array {
	setopt re_match_pcre
	[[ -v "$1" ]] && [[ "$(typeset -p -- "$1")" =~ "typeset\s*(-g)?\s*-[Aa]" ]]
}

# Check if argument is exclusively an associative array
function is_dict {
	setopt re_match_pcre
    [[ -v "$1" ]] && [[ "$(typeset -p -- "$1")" =~ "typeset\s*(-g)?\s*-A" ]]
}


##############################################
### A bit more complex argument functions
##############################################

# Check if argument is an IPv4
function is_ip_address {
	local usage=(
		"Usage: $(get_funcname) [OPTION...] IP_ADDRESS"
		"\t[-h|--help]"
		"\t[-4|--ipv4]"
		"\t[-6|--ipv6]"
	)

	## Setup parseopts
	local f_help is_ipv4 is_ipv6
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{4,-ipv4}=is_ipv4 \
		{6,-ipv6}=is_ipv6 \
		|| return $?

	## Help/usage message
	if (( ! $# )) || [[ "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	# Default to ipv4
	if [[ -z "${is_ipv4}${is_ipv6}" ]]; then
		is_ipv4="-4"
	# If both are defined, abort
	elif [[ -n "$is_ipv4" && -n "$is_ipv6" ]]; then
		print_invalidarg "-4 and -6 are mutually exclusive"
		return 2
	fi

	local regex_glob
	if [[ "$is_ipv4" ]]; then
		regex_glob='((2(5[0-5]|[0-4][0-9])|[01]?[0-9]{1,2})\.){3}(2(5[0-5]|[0-4][0-9])|[01]?[0-9]{1,2})'
		[[ "$1" =~ '^$' ]]
	elif [[ "$is_ipv6" ]]; then
		regex_glob='(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))'
	fi
	[[ "$1" =~ ^"$regex_glob"$ ]]
}

# Check if argument is IPv4 address or a hostname stored in /etc/hosts
function is_hostname {
	check_argc 1 1 $# || return $?
	is_ip_address "$1" && return 0

	local ip="${1%:*}"
	local port="${1#*:}"
	local arr=($(\grep -vE '^#' /etc/hosts | awk '{first = $1; $1 = ""; print $0 }'))
	[[ " ${arr[@]} " =~ " $ip " ]] && \
	[[ "$port" =~ ^[0-9]{1,5}$ ]]
}

# Check if argument is a valid date
function is_valid_date {
	local argdate="$1" fmt="${2:-%Y-%m}"

	case $(count_occurrences $fmt '-') in
	1 ) argdate+="-01" ;;
	0 ) argdate+="-01-01" ;;
	esac
	[[ "$(date --date="$argdate 00:00:00" "+$fmt" 2>/dev/null)" == "$1" ]]
}


##############################################
### String functions
##############################################

# Check if string $1 contains any substring from arguments (case-sensitive)
function str_contains {
	check_argc 2 0 $# || return $?
	local haystack="$1"
	shift

	while (( $# )); do
		[[ "$haystack" == *"$1"* ]] || return $?
		shift
	done
}

# Check if string $1 starts with substring $2
function str_starts_with {
	check_argc 2 2 $# || return $?
	[[ "$1" =~ ^"$2"* ]]
}

# Joins array of strings with delimiter
function str_join {
	local usage=(
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
	check_argc 2 0 $# || return $?
	# $1  - Haystack
	# $2+ - Needle(s)
	local haystack="$1"
	shift

	while (( $# )); do
		echo "${haystack}" | \grep -Fo "$1" | wc -l
		shift
	done
}


##############################################
### Array functions
##############################################

# Check if defined array $1 contains element $2
function array_has {
	check_argc 2 2 $# || return $?

	local array_name=$1
	local value=$2

	if ! is_array "$array_name"; then
		print_invalidarg "'$array_name' is not an array"
		return 1
	fi

	local array=(${(P)1})
	[[ " ${array[*]} " =~ " ${value} " ]]
}

# Check if defined associative array $1 contains key $2
function dict_has {
	check_argc 2 2 $# || return $?

	local array_name=$1
	local value=$2

	if ! is_dict "$array_name"; then
		print_invalidarg "'$array_name' is not an associative array"
		return 1
	fi

	local array=(${(P@k)1})
	[[ " ${array[*]} " =~ " ${value} " ]]
}

# Compares two dotted versions
function vercmp {
	check_argc 2 2 $# || return $?

	## If both arguments are equal
	[[ $1 == $2 ]] && return 0

	local IFS=.
	local i ver1=($1) ver2=($2)
	# fill empty fields in ver1 with zeros
	for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
		ver1[i]=0
	done
	# NOTE: zsh array indexation begins at 1, not 0
	for ((i=1; i<=${#ver1[@]}; i++)); do
		if [[ -z ${ver2[i]} ]]; then
			# fill empty fields in ver2 with zeros
			ver2[i]=0
		fi
		if ((10#${ver1[i]} > 10#${ver2[i]})); then
			return 1
		elif ((10#${ver1[i]} < 10#${ver2[i]})); then
			return 2
		fi
	done

	return 0
}


# Print formatted error message about invalid argument
function print_invalidarg {
	local msg="${2:-"Invalid argument"}"
	print_fn -e $@ "$msg: '%s'" "$1"
	# print_callstack
}

# Print formatted error message on variables (given as arguments) not being set
function print_noenv {
	if (( 1 <= $# )); then
		print_fn -w "Environment variable(s) not set:" "${(j:, :)@}"
	fi
}


##############################################
### Script functions
##############################################

# Use count of 'ext' statements until LINENO ($2) as next exit code for script ($1)
function script_exit_code {
	# $1 - $Script
	# $2 - $LINENO
	head -n $2 -- "$1" | grep -i -c "[e]xit"
}

# Sleeps, while displaying a message
function sleep_for {
	local usage=(
		"Usage: $(get_funcname) [OPTION...] [-t|--time=]<time_amount>"
		"\t[-h|--help]"
		"\t[-t|--time]"
		"\t[-m|--msg|--message]"
	)

	## Setup parseopts
	local f_help f_amount f_msg
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{t,-time}:=f_amount \
		{m,-msg,-message}:=f_msg \
		|| return $?

	## Help/usage message
	if (( ! $# )) || [[ "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	## Parse arguments
	local amount=0 msg
	[[ "$f_amount" ]] && amount=${f_amount[-1]}
	[[ "$f_msg" ]] && msg=${f_msg[-1]}

	while (( $# )); do
		case $1 in
		* )
			# if a number, consider it a time amount
			if (( ! $amount )) && is_num $1; then
				amount=$1
			elif [[ -z "$msg" ]]; then
				msg="$1"
			else
				printf "[$(get_funcname)] Unknown argument: '%s'\n" "$1"
			fi
		;;
		esac
		shift
	done

	# Setting default message
	msg="${msg:-Time left}"

	stop_fn() {
		tput cnorm
		trap - SIGINT SIGTERM
		echo
		if [[ "${1+x}" ]]; then
			kill -INT $$
		fi
	}
	tput civis

	trap "stop_fn 1 && return 1" SIGINT SIGTERM
	local pid
	while (( 0 < $amount )); do
		printf "\r%s: %d\033[0K" "$msg" $amount
		((amount--))
		sleep 1
	done

	stop_fn
}


##############################################
### Composite variable control
##############################################

# Checks if a defined variable $1 with semicolon-delimited values contains a given value $2
function hasvar {
	# If parent function is addvar or rmvar, impose argument restrictions
	if ! [[ "$(get_funcname 1)" =~ (add|rm)var ]]; then
		check_argc 2 2 $# || return $?
	fi

	# $1: name of the variable to check
	# $2: value to check
	local varvalue="${(P)1}"
	local val="$2"

	[[ "$varvalue" =~ (^|:)"$val"/?(:|$) ]]
}

# Adds value(s) in defined variable $1 if not in there. If no adding took place, return false
function addvar {
	# $1 : name of variable
	# $2 : 0 to prepend, 1 to append to variable
	# $2+: vars to add
	check_argc 2 0 $# || return $?

	local retval=1
	local varname="$1"
	shift

	local prepend=0
	while (( $# )); do
		## Define prepending flag if arg is an int
		if is_int $1; then
			prepend=$1
		## If given var exists & it's not set in variable
		elif ! hasvar $varname "$1"; then
			retval=0
			if (( $prepend )); then
				assign ${varname} "$1:${(P)varname}"
			else
				assign ${varname} "${(P)varname}:$1"
			fi
		fi
		shift
	done

	return $retval
}

# Removes value(s) from defined variable 1 if in there. If no removal took place, return false
function rmvar {
	# $1+: vars to remove
	check_argc 2 0 $# || return $?

	local retval=1
	local varname="$1"
	shift

	# Remove each item if existing in variable
	while (( $# )); do
		if hasvar "$varname" "$1"; then
			assign ${varname} "$(echo ${(P)varname} | sed -E "s#(^|:)/bin/?(:|$)#\2#g")"
			retval=0
		fi
		shift
	done

	return $retval
}


##############################################
### Environment control
##############################################
### PATH variable environment control

# Checks if argument exists in $path
function haspath {
	array_has path "$1"
}

# Adds argument(s) to $path if not set and if they're existing directories. Returns false if no path was set
function addpath {
	local -i retval=1

	# The index will help keep the order of the arguments set when prepending
	local -i idx=1
	local -i prepend=0
	while (( $# )); do
		## Define prepending flag if arg is an int
		if is_int $1; then
			prepend=$1
		elif haspath "$1"; then
			retval=0
		## If given path exists & it's not set in variable
		elif ! haspath "$1" && [[ -d "$1" ]]; then
			retval=0
			if (( $prepend )); then
				path[$idx,0]=("$1")
				((idx++))
			else
				path+=("$1")
			fi
		fi
		shift
	done

	return $retval
}

# Remove argument from $path. Returns false if no value was removed
function rmpath {
	local -i retval=1

	local -i idx
	while (( $# )); do
		idx=${path[(i)$1]}
		(( 0 < $idx && $idx <= ${#path[@]} )) && {
			path[$idx]=()
			retval=0
		}
		shift
	done

	return $retval
}
