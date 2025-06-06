### Network tools
# Define listen_ports as one of these, in order of preference
if command-has netstat; then
	alias listen_ports="netstat -ltpn"
elif command-has lsof; then
	alias listen_ports="sudo lsof -P 2>/dev/null | sed '1p;/LISTEN/!d'"
else
	alias listen_ports="echo 'netstat or lsof required but not installed'"
fi

### Hardware info
alias get-requested-cpu-clock='cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq'

function gpu-list {
	typeset -Al all_cmds=(
		[lshw]="-C display"
		[lspci]="-kd ::03xx"
	)

	# Check which commands are installed
	local cmd_name cmd_args
	for cmd_name in ${(@k)all_cmds}; do
		if ! command-has $cmd_name; then
			unset "all_cmds[$cmd_name]"
		fi
	done
	cmd_name=""

	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...] [-t|--tool=]<tool name>"
		"\t[-h|--help]"
		"\t[-t|--tool]"
	)

	## Setup parseopts
	local f_help f_tool
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{t,-tool}:=f_tool \
		|| return $?

	## Help/usage message
	if { (( ! $# )) && [[ -z "${f_tool}" ]] } || [[ "$f_help" ]]; then
		>&2 print -l $usage
		printf "Avaliable tools are:\n\t%s\n" "${(*k)all_cmds}"
		[[ "$f_help" ]]; return $?
	fi

	#
	[[ "${f_tool}" ]] && cmd_name="${f_tool[-1]}"

	# Set from args
	while (( $# )); do
		if [[ "$cmd_name" ]]; then
			print_fn -e "Arguments discarded: You may pick just 1 tool"
			return 1
		elif dict_has all_cmds "$1"; then
			cmd_name="$1"
		else
			print_fn -w "Invalid or unsupported tool: '$1'"
		fi
		shift
	done

	# TODO: If no args, begin interactive selection

	# Error checking
	if [[ -z "$cmd_name" ]]; then
		print_fn -e "No tool provided"
		return 1
	elif ! dict_has all_cmds "$cmd_name"; then
		print_fn -e "Invalid or unsupported tool: '$cmd_name'"
		return 2
	fi

	cmd_args=(${(z)all_cmds[$cmd_name]})
	sudo ${cmd_name} ${cmd_args}
}


### System tools
function kill_zombies {
	kill -HUP $(ps -A -ostat,ppid | awk '/[zZ]/{ print $2 }')
}

# Get total size of given directory
function du_hast {
	du -hs $@ | sort -rh
}

### Memory
function meminfo {
	local -r usage=("Usage: ${funcstack[1]} [OPTION...] IP_ADDRESS"
		"\t[-h|--help]"
		"\t[-a|--all]   : Prints Usable memory / Total memory (default)"
		"\t[-f|--free]  : Prints Usable memory"
		"\t[-t|--total] : Prints Total memory"
	)

	## Setup func opts
	local f_all f_free f_total
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{a,-all}=f_all \
		{f,-free}=f_free \
		{t,-total}=f_total \
		|| return 1

	## Help/usage message
	if [[ "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	## Default --all flag
	elif (( ! $# )); then
		f_all=1
	fi

	## Parse arguments
	[[ "$f_all" ]] && {
		f_free=1
		f_total=1
	}

	local memUsable memTotal
	local memory

	if [[ "$f_free" ]]; then
		# Search for MemAvailable. If non-existant, search for MemFree
		memUsable="$(grep MemAvailable /proc/meminfo | awk {'print $2'})"
		[[ -z "$memUsable" ]] && memUsable="$(grep MemFree /proc/meminfo | awk {'print $2'})"

		memUsable="$(( $memUsable / 1000 ))"
		memUsable="$(echo $memUsable | sed ':a;s/\B[0-9]\{3\}\>/ &/;ta') MB"
	fi

	if [[ "$f_total" ]]; then
		memTotal="$(( $(grep MemTotal /proc/meminfo | awk {'print $2'}) / 1000 ))"
		memTotal="$(echo $memTotal | sed ':a;s/\B[0-9]\{3\}\>/ &/;ta') MB"
	fi

	if [[ "$memUsable" ]] && [[ "$memTotal" ]]; then
		memory="$memUsable (Usable) / $memTotal (Total)"
	elif [[ "$memUsable" ]]; then
		memory="$memUsable"
	elif [[ "$memTotal" ]]; then
		memory="$memTotal"
	fi

	## Print result
	[[ "$memory" ]] && echo "$memory"
}

### Drives
function disk_speedtest {
	local dd_params=(bs count oflag conv)
	local dd_line=(
		1G:1:dsync:
		64M:1:dsync:
		1M:256::fdatasync
		8k:10k::
		1M:10k::
		512:1000:dsync:
	)
	local idx_test idx_params
	for ((idx_test=1; idx_test <= ${#dd_line[@]}; idx_test++)); do
		local line="${dd_line[$idx_test]}"
		local params=("${(@s/:/)line}")
		local args=()

		for ((idx_params=1; idx_params <= ${#dd_params[@]}; idx_params++)); do
			local param_name=${dd_params[$idx_params]}
			local param_value=${params[$idx_params]}
			if [[ "$param_value" ]]; then
				args+=($param_name=$param_value)
			fi
		done

		echo "Testing for ${params[1]} blocks in ${params[2]} iteration(s)"
		dd if=/dev/zero of=/tmp/test${idx_test}.img ${args[@]}
	done

	rm -f /tmp/test*.img
}

# Package Managers
typeset -Ag PKGMGR_OS=(
	[yum]=redhat-release
	[pacman]=arch-release
	[emerge]=gentoo-release
	[zypp]=SuSE-release
	[apt-get]=debian_version
	[apk]=alpine-release
)

# Package Manager list commands
typeset -Ag PKGMGR_LIST=(
	[pacman]="Ql"
)

# Obtains the package manager depending on the release file
function pkgmgr-get {
	local pkgmgr release_file
	for pkgmgr release_file in ${(@kv)PKGMGR_OS}; do
		if [[ -f "/etc/$release_file" ]] && command -v "$pkgmgr" &>/dev/null; then
			echo "${pkgmgr}"
			return 0
		fi
	done
	return 1
}

function pkgmgr-binpath {
	local retval=0
	local pkgmgr="$(pkgmgr-get)"

	if ! dict_has PKGMGR_LIST "$pkgmgr"; then
		print_fn -e "Case for '$pkgmgr' not implemented yet"
		return 1
	fi

	local arg
	for arg; do
		$pkgmgr -${PKGMGR_LIST[$pkgmgr]} "$arg" | \grep -Eo -m1 '/usr(/.+)?/bin/[^/]+'
		(( $? && ! $retval )) && retval=1
	done

	return $retval
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
