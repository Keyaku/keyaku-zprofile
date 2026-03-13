if ! whatami Android; then
	### Session type (X11, Wayland) configuration
	if [[ -z "${XDG_SESSION_TYPE}" ]] && command-has loginctl; then
		export XDG_SESSION_TYPE="$(loginctl show-session $(awk '/tty/ {print $1}' <(loginctl)) -p Type | awk -F= '{print $2}')"
	fi

# if actually on Android (Termux)
elif (( ${+TERMUX_VERSION} )) && [[ "${TERMUX__PREFIX:P}" == "/data/data/com.termux/files/usr" ]]; then
	# Silence Message of the Day (motd)
	if [[ -f "$HOME"/../usr/etc/motd ]]; then
		mv "$HOME"/../usr/etc/motd{,.old}
	fi
	# Apply rish (Shizuku) configuration
	if [[ -d "$HOME"/.termux/rish.d && -f "$HOME"/.termux/rish.d/rish ]]; then
		(rish_exec=($(echo "$HOME"/.termux/rish.d/rish(.NxE)))
			(( 0 == ${#rish_exec} )) && chmod ug+x "$HOME"/.termux/rish.d/rish
		)
		if [[ ! -L "$HOME"/.local/bin/rish ]]; then
			rm -f "$HOME"/.local/bin/rish
			ln -s "$HOME"/.termux/rish.d/rish "$HOME"/.local/bin/rish
		fi
		[[ "${RISH_APPLICATION_ID}" == "com.termux" ]] || export RISH_APPLICATION_ID="com.termux"
	fi
fi
