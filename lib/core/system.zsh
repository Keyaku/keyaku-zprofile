# Sleeps while displaying a message
function sleep_for {
	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...] [-t|--time=]<time_amount>"
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

# Kills/clears zombie processes
function kill_zombies {
	kill -HUP $(ps -A -ostat,ppid | awk '/[zZ]/{ print $2 }')
}


### Systemd
function has_systemd {
	# (( ${+commands[systemctl]} )) && systemctl -q is-system-running
	[[ -r /run/systemd/sessions ]] && [[ "$(echo /run/systemd/sessions/<->##(N))" ]]
}

if has_systemd; then
	### Systemd specific
	function systemctl-service-path {
		systemctl cat $@ 2>/dev/null | sed -En 's~# (.+?\.service)~\1~p'
	}

	alias systemctl-show-unitpath='systemctl show -p UnitPath --value'

	### Udev control
	alias udev-reload='sudo udevadm control --reload-rules && sudo udevadm trigger && sudo systemctl restart systemd-udevd.service'
fi
