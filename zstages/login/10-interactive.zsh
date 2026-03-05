### Last execution to run if in an interactive shell
[[ -o interactive ]] || return

if ! whatami Android; then
	### Session type (X11, Wayland) configuration
	if [[ -z "${XDG_SESSION_TYPE}" ]] && command-has loginctl; then
		export XDG_SESSION_TYPE="$(loginctl show-session $(awk '/tty/ {print $1}' <(loginctl)) -p Type | awk -F= '{print $2}')"
	fi
fi
