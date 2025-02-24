##############################################
### Argument functions
##############################################

# Check if argument is an integer
function is_int {
	while (( $# )); do
		[[ "$1" =~ ^-?[0-9]+$ ]] || return $?
		shift
	done
}

# Check if argument is a number
function is_num {
	while (( $# )); do
		[[ $1 =~ ^[+-]?[0-9]+([.][0-9]+)?$ ]] || return $?
		shift
	done
}

# Check if argument is any type of array (including associative/dictionary)
function is_array {
	setopt re_match_pcre
	while (( $# )); do
		[[ -v "$1" ]] && [[ "$(typeset -p -- "$1")" =~ "typeset\s*(-g)?\s*-[Aa]" ]] \
			|| return $?
		shift
	done
}

# Check if argument is exclusively an associative array
function is_dict {
	setopt re_match_pcre
	while (( $# )); do
   		[[ -v "$1" ]] && [[ "$(typeset -p -- "$1")" =~ "typeset\s*(-g)?\s*-A" ]] \
			|| return $?
		shift
	done
}


##############################################
### A bit more complex argument functions
##############################################

# Compares two dotted versions
function vercmp {
	check_argc 2 2 $#

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
	check_argc 1 1 $#
	is_ip_address "$1" && return 0

	local ip="${1%:*}"
	local port="${1#*:}"
	local arr=($(\grep -vE '^#' /etc/hosts | awk '{first = $1; $1 = ""; print $0 }'))
	[[ " ${arr[@]} " =~ " $ip " ]] && \
	[[ "$port" =~ ^[0-9]{1,5}$ ]]
}

# Check if argument is a valid date
function is_valid_date {
	check_argc 1 2 $#
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

# Check if defined array $1 contains value(s) ${@:2}
function array_has {
	check_argc 2 0 $#

	if ! is_array "$1"; then
		print_fn -e "not an array: '$1'"
		return 1
	fi

	local array=(${(P)1})
	shift
	while (( $# )); do
		[[ " ${array} " =~ " $1 " ]] || return $?
		shift
	done
}

# Check if defined associative array $1 contains key(s) ${@:2}
function dict_has {
	check_argc 2 0 $#

	if ! is_dict "$1"; then
		print_fn -e "not an associative array: '$1'"
		return 1
	fi

	local array=(${(P@k)1})
	shift
	while (( $# )); do
		[[ " ${array} " =~ " $1 " ]] || return $?
		shift
	done
}
