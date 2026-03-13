# Sleeps while displaying a message
function sleep_for {
	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...] [-t|--time=]<time_amount>"
		"\t[-h|--help]                    : Print this help message"
		"\t[-t|--time] <amount>           : Time to sleep in seconds"
		"\t[-m|--msg|--message] <message> : Message to display. Default: 'Time left'"
		"\t[-c|--clear]                   : Clear the countdown line on completion"
	)

	## Setup parseopts
	local f_help f_amount f_msg f_clear
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{t,-time}:=f_amount \
		{m,-msg,-message}:=f_msg \
		{c,-clear}=f_clear \
		|| return $?

	## Help/usage message
	if [[ -n "$f_help" ]]; then
		>&2 print -l $usage
		return 0
	fi

	## Parse arguments
	local -i amount=0
	local msg
	[[ -n "$f_amount" ]] && amount=${f_amount[-1]}
	[[ -n "$f_msg" ]] && msg=${f_msg[-1]}

	# Consume remaining positional arguments
	local arg
	for arg; do
		if (( ! $amount )) && [[ $arg == <-> ]]; then
			amount=$arg
		elif [[ -z "$msg" ]]; then
			msg="$arg"
		else
			print_fn -e "Unknown argument: '%s'" "$arg"
			return 1
		fi
	done

	# Validate amount
	check_argc $# 0 || return 1
	(( amount > 0 )) || return 0

	# Setting default message
	msg="${msg:-Time left}"

	zmodload zsh/datetime

	local stop_fn
	stop_fn() {
		tput cnorm
		trap - SIGINT SIGTERM
		unfunction stop_fn
		[[ -z "${1+x}" && -n "$f_clear" ]] || echo
		if [[ "${1+x}" ]]; then
			kill -INT $$
		fi
	}

	trap 'stop_fn 1' SIGINT SIGTERM
	tput civis

	local -F start_time=$EPOCHREALTIME
	local -F end_time=$(( start_time + amount ))
	local -i remaining

	while (( EPOCHREALTIME < end_time )); do
		remaining=$(( end_time - EPOCHREALTIME ))
		printf "\r%s: %d\033[0K" "$msg" $(( remaining + 1 ))
		sleep $(( remaining - int(remaining) > 0 ? remaining - int(remaining) : 1 ))
	done

	if [[ -n "$f_clear" ]]; then
		printf "\r\033[0K"
	fi

	stop_fn
}

# Kills/clears zombie processes
function kill_zombies {
	ps -A -ostat,ppid | awk '/[zZ]/{ print $2 }' | xargs -r kill -HUP
}


### Systemd
function has_systemd {
	local -a sessions=( /run/systemd/sessions/<->##(N-.) )
	[[ -d /run/systemd/system ]] \
		&& [[ "$(</proc/1/comm)" == "systemd" ]] \
		&& (( ${#sessions} ))
}

if has_systemd; then
	### Systemd specific
	function systemctl-service-path {
		systemctl cat "$@" 2>/dev/null | sed -En 's~# (.+?\.service)~\1~p'
	}

	alias systemctl-show-unitpath='systemctl show -p UnitPath --value'

	### Udev control
	alias udev-reload='sudo udevadm control --reload-rules && sudo udevadm trigger && sudo systemctl restart systemd-udevd.service'
fi
