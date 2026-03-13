##############################################
### Argument functions
##############################################

# Check if argument is an integer
function is_int {
	local arg
	(( $# )) && for arg; do
		[[ $arg == <-> ]] || return $?
	done
}

# Check if argument is a number
function is_num {
	local arg
	(( $# )) && for arg; do
		[[ $arg =~ ^[+-]?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$ ]] || return $?
	done
}

# Check if arguments are of type array
function is_array {
	local arg
	(( $# )) && for arg; do
		[[ -v "$arg" && ${(Pt)arg} == *array* ]] || return $?
	done
}

# Check if arguments are of type associative array
function is_associative_array {
	local arg
	(( $# )) && for arg; do
		[[ -v "$arg" && ${(Pt)arg} == *association* ]] || return $?
	done
}


##############################################
### A bit more complex argument functions
##############################################

# Compares two dotted versions
function vercmp {
	check_argc $# 2 2 || return 1

	[[ $1 == $2 ]] && return 0

	local IFS=.
	local -a ver1=("${(s:.:)1}") ver2=("${(s:.:)2}")
	local -i i

	# Pad ver1 with zeros to match ver2 length
	for ((i=${#ver1}+1; i<=${#ver2}; i++)); do
		ver1[i]=0
	done

	for ((i=1; i<=${#ver1}; i++)); do
		# Pad ver2 with zeros if necessary
		[[ -z ${ver2[i]} ]] && ver2[i]=0

		if (( 10#${ver1[i]} > 10#${ver2[i]} )); then
			return 1
		elif (( 10#${ver1[i]} < 10#${ver2[i]} )); then
			return 2
		fi
	done

	return 0
}

# Check if argument is an IPv4
function is_ip_address {
	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...] IP_ADDRESS"
		"\t[-h|--help] : Print this help message"
		"\t[-4|--ipv4] : Specify that the argument should be tested as IPv4 [Default]"
		"\t[-6|--ipv6] : Specify that the argument should be tested as IPv6"
	)

	## Setup parseopts
	local f_help is_ipv4 is_ipv6
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{4,-ipv4}=is_ipv4 \
		{6,-ipv6}=is_ipv6 \
		|| return $?

	## Help/usage message
	if [[ -n "$f_help" ]]; then
		>&2 print -l $usage
		return 0
	fi

	check_argc $# 1 1 || return 1

	if [[ -n "$is_ipv4" && -n "$is_ipv6" ]]; then
		print_fn -e "-4 and -6 are mutually exclusive"
		return 2
	fi

	local -r ipv4_re='(25[0-5]|(2[0-4]|1?[0-9]){0,1}[0-9])(\.(25[0-5]|(2[0-4]|1?[0-9]){0,1}[0-9])){3}'
	local -r ipv6_re='([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]+|::(ffff(:0{1,4})?:)?((25[0-5]|(2[0-4]|1?[0-9]){0,1}[0-9])\.){3}(25[0-5]|(2[0-4]|1?[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1?[0-9]){0,1}[0-9])\.){3}(25[0-5]|(2[0-4]|1?[0-9]){0,1}[0-9])'
	local -r port_re='([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])'

	local input="$1"

	function _match_ipv4 {
		[[ "$input" =~ ^"$ipv4_re"$"|"^"$ipv4_re":"$port_re"$ ]]
	}

	function _match_ipv6 {
		# Bare IPv6 (no brackets, no port)
		[[ "$input" =~ ^"$ipv6_re"$ ]] || \
		# Bracketed IPv6 with port
		[[ "$input" =~ ^"\[$ipv6_re\]":"$port_re"$ ]]
	}

	local -i retval
	if [[ -n "$is_ipv4" ]]; then
		_match_ipv4; retval=$?
	elif [[ -n "$is_ipv6" ]]; then
		_match_ipv6; retval=$?
	else
		_match_ipv4 || _match_ipv6; retval=$?
	fi

	unfunction _match_ipv4 _match_ipv6
	return $retval
}

# Check if argument is IPv4 address or a hostname stored in /etc/hosts
function is_hostname {
	local ip="${1}"

	is_ip_address "$ip" && return 0

	awk '/^#/{next} {for(i=2;i<=NF;i++) if($i==ip){found=1; exit}} END{exit !found}' \
		ip="$ip" /etc/hosts || return 1
}

# Check if argument is a valid date
function is_valid_date {
	local argdate="$1"
	local fmt="${2:-%Y-%m-%d}"

	# Pad date and format based on missing components
	local -i dashes=$(( ${#argdate} - ${#${argdate//-/}} ))
	case $dashes in
	1 ) argdate+="-01" ;;
	0 ) argdate+="-01-01" ;;
	esac

	if [[ "$OSTYPE" == darwin* ]]; then
		date -j -f "$fmt" "$argdate" &>/dev/null
	else
		date -d "$argdate" +"$fmt" &>/dev/null
	fi
}


##############################################
### Array functions
##############################################

# Check if defined array $1 contains value(s) ${@:2}
function array_has {
	if ! is_array "$1"; then
		print -u2 "not an array: '$1'"
		return 1
	fi

	local -a array=(${(P)1})
	local -a args=(${@:2})
	# result is any element(s) left subtracted from the following operation
	(( 0 == ${#args:|array} ))
}

# Check if defined associative array $1 contains key(s) ${@:2}
function array_keys_has {
	if ! is_associative_array "$1"; then
		print -u2 "not an associative array: '$1'"
		return 1
	fi

	local -a array=(${(P@k)1})
	local -a args=(${@:2})
	# result is any element(s) left subtracted from the following operation
	(( 0 == ${#args:|array} ))
}
