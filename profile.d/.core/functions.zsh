##############################################
### Argument functions
##############################################

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

# Check if argument is an IPv4
function is_ip_address {
	local -r usage=(
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
		print_fn -e "-4 and -6 are mutually exclusive"
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
	check_argc 1 2 $# || return $?
	local argdate="$1" fmt="${2:-%Y-%m}"

	case $(count_occurrences $fmt '-') in
	1 ) argdate+="-01" ;;
	0 ) argdate+="-01-01" ;;
	esac
	[[ "$(date --date="$argdate 00:00:00" "+$fmt" 2>/dev/null)" == "$1" ]]
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
		print_fn -e "not an array: '$array_name'"
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
		print_fn -e "not an associative array: '$array_name'"
		return 1
	fi

	local array=(${(P@k)1})
	[[ " ${array[*]} " =~ " ${value} " ]]
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
	check_argc 2 2 $# || return $?
	# $1 - $Script
	# $2 - $LINENO
	head -n $2 -- "$1" | grep -i -c "[e]xit"
}

# Sleeps, while displaying a message
function sleep_for {
	local -r usage=(
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
	local -i amount=0
	local msg
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
				print_fn -e "Unknown argument: '%s'\n" "$1"
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
