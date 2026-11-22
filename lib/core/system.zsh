# The repo this environment runs from. Usually $ZDOTDIR itself, but root's sparse
# ZDOTDIR (see setup_root) only links lib/ and friends, so resolve this file's
# real path instead; repo-level files like .gitmodules live there.
typeset -g ZPROFILE_REPO=${${(%):-%x}:A:h:h:h}

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
	[[ -d /run/systemd/system ]] \
		&& [[ "$(</proc/1/comm)" == "systemd" ]] \
		&& (( ${#:-/run/systemd/sessions/<->##(N-.)} ))
}

# True only when the user's own session bus is reachable (i.e. safe to call `systemctl --user`)
function has_user_systemd {
	[[ -n "${XDG_RUNTIME_DIR}" ]] && has_systemd
}

if has_systemd; then
	### Systemd specific
	function systemctl-service-path {
		local out=$(systemctl cat "$@" 2>/dev/null | awk '/^# /{sub(/^# /, ""); print; exit}')
		[[ -n "$out" ]] && echo "$out"
	}

	alias systemctl-show-unitpath='systemctl show -p UnitPath --value'

	### Udev control
	alias udev-reload='sudo udevadm control --reload-rules && sudo udevadm trigger && sudo systemctl restart systemd-udevd.service'
fi

# Whether the vendored submodule NAME is enabled. NAME is the last component of
# its .gitmodules path (ohmyzsh, powerlevel10k, zsh-syntax-highlighting).
# Enabled unless the user set `zstyle ':zprofile:submodules:NAME' enabled no`
# (e.g. in $ZDOTDIR/user/settings.zsh). A disabled submodule is neither
# fetched by `zupdate --submodules` nor loaded.
function _zsubmodule_enabled {
	zstyle -T ":zprofile:submodules:${1:t}" enabled
}

# Shared implementation of zext and zsubmod. Sets `zstyle "CTX:NAME" enabled
# yes|no` for every NAME after --on/--off; with no arguments, lists each known
# NAME and whether it's enabled. Parsed by hand because zparseopts can't take a
# list of values per flag.
function _ztoggle {
	local -r ctx=$1 kind=$2 known_var=$3
	shift 3
	local -a known=(${(P)known_var})
	local -r usage=(
		"Usage: ${funcstack[2]} [(--on|--off) NAME...]..."
		"\t[-h|--help]     : Print this help message"
		"\t[--on NAME...]  : Enable each ${kind} named"
		"\t[--off NAME...] : Disable each ${kind} named ('*' matches all; a name always wins over '*')"
		"With no arguments, lists each ${kind} and whether it's enabled."
		"Changes apply to shells started afterwards; call it from \$ZDOTDIR/user/settings.zsh to keep them."
	)

	if (( ! $# )); then
		local name
		for name in ${known}; do
			zstyle -T "${ctx}:${name}" enabled && printf '%-28s on\n' "$name" || printf '%-28s off\n' "$name"
		done
		return 0
	fi

	local arg flag state
	local -i pending=0
	for arg; do
		case $arg in
		-h|--help ) >&2 print -l $usage; return 0 ;;
		--on|--off )
			(( pending )) && { print_fn -e "Option $flag needs at least one name"; return 1 }
			flag=$arg; state=${${arg:#--on}:+no}; state=${state:-yes}; pending=1
		;;
		-* ) print_fn -e "Unknown option: $arg"; >&2 print -l $usage; return 1 ;;
		* )
			[[ -z "$flag" ]] && { print_fn -e "'$arg' must follow --on or --off"; return 1 }
			[[ "$arg" == '*' ]] || (( ${known[(Ie)$arg]} )) || print_fn -w "No such ${kind}: $arg"
			zstyle "${ctx}:${arg}" enabled $state
			pending=0
		;;
		esac
	done
	(( pending )) && { print_fn -e "Option $flag needs at least one name"; return 1 }
	return 0
}

# Enables or disables extensions (directories under $ZDOTDIR/extensions).
# See _ztoggle for the arguments; e.g. `zext --off docker vscode --on pass`.
function zext {
	local -a known=("$ZDOTDIR"/extensions/*(N/:t))
	_ztoggle ':zprofile:extensions' extension known "$@"
}

# Enables or disables vendored git submodules (ohmyzsh, powerlevel10k,
# zsh-syntax-highlighting). See _ztoggle and _zsubmodule_enabled.
function zsubmod {
	local -a known
	[[ -r "$ZPROFILE_REPO/.gitmodules" ]] && \
		known=(${${(M)${(f)"$(<"$ZPROFILE_REPO/.gitmodules")"}:#(|*[[:blank:]])path*=*}##*[=/[:blank:]]})
	_ztoggle ':zprofile:submodules' submodule known "$@"
}

# Finds a copy of the submodule NAME installed by the system's package manager
# and sets REPLY to its entry file (fails when there's none, or NAME has no
# known locations). Sets REPLY instead of printing so callers don't fork.
function _zsubmodule_system_path {
	local -a candidates=()
	case $1 in
	zsh-syntax-highlighting )
		candidates=(
			/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh  # Arch
			/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh  # Debian, Ubuntu, Fedora
			/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh  # Homebrew (Intel), BSD
			/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh  # Homebrew (Apple Silicon)
		)
		[[ -n "$PREFIX" ]] && candidates+=("$PREFIX"/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh)  # Termux
	;;
	powerlevel10k )
		candidates=(
			/usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme  # Arch (zsh-theme-powerlevel10k)
			/usr/local/share/powerlevel10k/powerlevel10k.zsh-theme  # Homebrew (Intel)
			/opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme  # Homebrew (Apple Silicon)
			/run/current-system/sw/share/zsh-powerlevel10k/powerlevel10k.zsh-theme  # NixOS
		)
	;;
	esac
	local -a found=(${^candidates}(N.))
	(( ${#found} )) || return 1
	REPLY="${found[1]}"
}
