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
		print_error "This function does not work with arrays!"
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
		print_error "Argument mismatch: [$minargs-$maxargs] required, $argc given."
		print_callstack
		return 2
	}
}

# Get function name relative to current function. Accepts int to reach higher levels if necessary
function get_funcname {
	local idx=2
	if is_int $1 && (( 0 < $1 )); then
		idx=$((idx + $1))
	fi
	echo "${funcstack[$idx]:-$FUNCNAME[$idx]}"
}

# Check if argument is an integer
function is_int {
	[[ $1 =~ ^[0-9]+$ ]]
}

# Check if argument is a number
function is_num {
	[[ $1 =~ ^[+-]?[0-9]+([.][0-9]+)?$ ]]
}

# Check if argument is any type of array (including associative/dictionary)
function is_array {
	[[ -v "$1" ]] && [[ "$(typeset -p -- "$1")" =~ "typeset\s*(-g)?\s*-[Aa]" ]]
}

# Check if argument is exclusively an associative array
function is_dict {
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

# Prompt via read. Incorporates question and looping until non-empty REPLY
function ask {
	local usage=(
		"Usage: $(get_funcname) [OPTION...] [(-p|--prompt) message]"
		"\t[-h|--help]"
		"\t[-k|--non-empty] : Prohibit empty answers"
		"\t[-p|--prompt] : Defines question for the prompt"
		"\t[-o|--opts] : Add possible answer(s)"
		"\t[-d|--default] : Make argument the default answer if empty"
		"\t[-s|--strict] : Paired with (-o|--options), will not allow any answer outside the available ones"
	)

	## Setup parseopts
	local f_help f_nonEmpty f_prompt f_options f_default f_strict
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{k,-non-empty}=f_nonEmpty \
		{p,-prompt}:=f_prompt \
		{o,-opts}+:=f_options \
		{d,-default}:=f_default \
		{s,-strict}=f_strict

	## Help/usage message
	if [[ "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	## Parse arguments
	local v_prompt v_default v_options=()
	[[ "${f_prompt}" ]] && v_prompt="${f_prompt[-1]}"
	[[ "${f_options}" ]] && {
		v_options=(${f_options/(-o|--opts)/})
	}
	[[ "${f_default}" ]] && {
		v_default="${f_default[-1]:l}"
		## Uppercase default option
		if array_has v_options "${v_default:l}"; then
			local idx=${v_options[(i)${v_default:l}]}
			v_options[$idx]=("${v_default:u}")
		else
			v_options=("${v_default:u}" ${v_options})
		fi
	}
	# If strict was requested but there are no options, clear this flag
	if [[ "$f_strict" ]] && (( ! ${#v_options} )); then
		f_strict=""
	fi

	while (( $# )); do
		case $1 in
		-* ) print_invalidarg "$1"
		;;
		* )
			# if a number, consider it a time amount
			if [[ -z "$v_prompt" ]]; then
				v_prompt="${1}"
			else
				printf "[$(get_funcname)] Discarded argument: '%s'\n\t%s\n" "$1" "Prompt message already defined"
			fi
		;;
		esac
		shift
	done

	## Prepare prompt message
	v_prompt="${v_prompt:+$v_prompt }${v_options:+[${v_options// //}]}"
	[[ "${v_prompt}" ]] && v_prompt="${v_prompt}\n"

	## Begin prompting
	local v_answer
	REPLY=""
	while [[ -z "${v_answer}" ]]; do
		printf "${v_prompt}> "
		read

		if [[ "$f_nonEmpty" ]] && [[ -z "${REPLY}" ]]; then
			echo "Answer cannot be empty."
		elif [[ "$f_strict" ]] && ! array_has v_options "${REPLY:l}"; then
			printf "Invalid answer: '%s'\n" "${REPLY}"
		elif [[ "${v_default}" ]]; then
			v_answer="${v_default}"
		else
			v_answer="$REPLY"
			break
		fi
	done
	REPLY="$v_answer"
}

function ask_yn {
	local valid_y=(yes ye y)
	local valid_n=(no n)
	local valid_answers=(${valid_y[@]} ${valid_n[@]})

	## Setup parseopts
	local f_default
	zparseopts -D -F -K -- \
		{d,-default}:=f_default \
		|| return $?

	## Parse arguments
	local v_default
	if [[ "${f_default}" ]]; then
		v_default="${f_default[-1]:l}"
		if [[ "${v_default}" ]] && ! array_has valid_answers "$v_default"; then
			print_invalidarg "$v_default" "Invalid default value"
			return 1
		fi
		f_default[-1]="$v_default[1]"
	fi

	## Begin prompting
	REPLY=""
	while :; do
		ask -o y -o n ${f_default} $@
		REPLY="${REPLY:l}"

		array_has valid_answers "${REPLY}" && break
		printf "Invalid answer: '%s'\n" "${REPLY}"
	done

	array_has valid_y "$REPLY"
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

	# Default is zsh, but contain bash alternative just in case
	local array
	if [[ ${SHELL##*/} == zsh ]]; then
		array=($(echo ${(P)1} | sed 's/^(//g;s/)$//g'))
	else
		array=($(echo ${!array_name} | sed 's/^(//g;s/)$//g'))
	fi

	[[ " ${array[*]} " =~ " ${value} " ]]
}

# Check if defined associative array $1 contains key $2
function array_key {
	check_argc 2 2 $# || return $?

	local array_name=$1
	local value=$2

	if ! is_dict "$array_name"; then
		print_invalidarg "'$array_name' is not an associative array"
		return 1
	fi

	# Default is zsh, but contain bash alternative just in case
	local array
	if [[ ${SHELL##*/} == zsh ]]; then
		array=(${(P@k)1})
	else
		array=(${!1})
	fi
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

# Transform arguments to lowercase
function to_lower {
	[[ ${SHELL##*/} == zsh ]] && echo "${@:l}" || echo "${@,,}"
}

# Transform arguments to uppercase
function to_upper {
	[[ ${SHELL##*/} == zsh ]] && echo "${@:u}" || echo "${@^^}"
}

# Print callstack
function print_callstack {
	local count idx_stack idx_trace

	echo "Call stack:"
	for ((count=1, idx_stack=2, idx_trace=1; idx_stack <= ${#funcstack[@]}; count++, idx_stack++, idx_trace++)); do
		local src=(${(s[:])funcfiletrace[$idx_trace]})
		local caller="${funcstack[$idx_stack]}"
		printf "\t%d. ${fg_no_bold[yellow]}%s${reset_color} > %s:%d\n" $count "$caller" "${src[1]:t}" ${src[2]}
	done
}

# Prints formatted error message
function print_error {
	# Print function name in green, or nothing if not in a function
	local fn_name="$(get_funcname 1)"
	[[ "$fn_name" ]] && fn_name="${fg_no_bold[green]}[$fn_name]${reset_color} "

	# Print message via stderr as well
	>&2 printf "%s${fg_bold[red]}ERROR${fg_no_bold[red]}:${reset_color} %s\n" "$fn_name" "$(printf "$1" ${@:2})"
}

# Print formatted error message about invalid argument
function print_invalidarg {
	local msg="${2:-"Invalid argument"}"
	print_error "$msg: '%s'" "$1"
	# print_callstack
}

# Print formatted error message on variables (given as arguments) not being set
function print_noenv {
	if (( 1 <= $# )); then
		print_error "Environment variable(s) not set:" "${(j:, :)@}"
	fi
}

# Prints formatted warning message
function print_warn {
	# Print function name in green, or nothing if not in a function
	local fn_name="$(get_funcname 1)"
	[[ "$fn_name" ]] && fn_name="${fg_no_bold[green]}[$fn_name]${reset_color} "

	# Print message via stderr as well
	>&2 printf "%s${fg_bold[yellow]}WARN${fg_no_bold[yellow]}:${reset_color} %s\n" "$fn_name" "$*"
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
### Updates all current user's environment variables from profile.d
function env_update {
	local env_list=()
	env_list=($(env_find ${@:-'.*'}))
	local retval=$?

	set -- ${env_list}
	while (( $# )); do
		source "$1" || return $?
		shift
	done

	return $retval
}

# Find env files in under profile.d
function env_find {
	local usage=(
		"Usage: $(get_funcname) [OPTION...] FILENAME"
		"\t[-h|--help]"
	)

	## Setup parseopts
	local f_help f_dir f_file
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{d,-dir}=f_dir \
		{f,-file}=f_file \
		|| return $?

	## Help/usage message
	if (( ! $# )) || [[ "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	# Join all arguments into one regex-able pattern as $1|$2|..|$N
	local args="${(j:|:)@}"

	local regex_pattern="($args)(/.+)?"
	if [[ "$f_dir" ]]; then
		regex_pattern="($args)/.+"
	elif [[ "$f_file" ]]; then
		regex_pattern="($args)"
	fi

	local retval=0

	# Search within all defined paths in env dirs
	local env_dirs=("${ZDOTDIR}/profile.d")
	local pdir
	for pdir in $env_dirs; do
		find "$pdir" -type f -regextype posix-extended -regex ".*/$regex_pattern\.(env|\w*sh)" -not -path '*/.stversions/*' | \grep .
		(( $? && 0 == $retval )) && retval=1
	done

	return $retval
}

### PATH variable environment control

# Checks if argument exists in $path
function haspath {
	array_has path "$1"
}

# Adds argument(s) to $path if not set and if they're existing directories. Returns false if no path was set
function addpath {
	local retval=1

	# The index will help keep the order of the arguments set when prepending
	local idx=1
	local prepend=0
	while (( $# )); do
		## Define prepending flag if arg is an int
		if is_int $1; then
			prepend=$1
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
	local retval=1

	local idx
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
