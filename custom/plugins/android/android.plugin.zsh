# if NOT on Android
if ! whatami Android; then
	if (( ${+commands[adb]} )) || [[ -d "${XDG_DATA_HOME}/android" ]]; then
		# Start Shizuku on connected device (non-root)
		alias shizuku-start='adb shell sh /sdcard/Android/data/moe.shizuku.privileged.api/start.sh'

		# Android debugging
		export ANDROID_HOME="${XDG_DATA_HOME}/android"
		[[ -d "$ANDROID_HOME" ]] || mkdir -p "$ANDROID_HOME"
		export ANDROID_USER_HOME="${ANDROID_HOME}/.android"

		if (( ${+commands[adb]} )); then
			# Prevent adb from using user's home directory
			alias adb="HOME=$ANDROID_HOME ${commands[adb]}"
			alias fastboot="HOME=$ANDROID_HOME ${commands[fastboot]}"
		fi
	fi
# if actually on Android (Termux)
elif (( ${+TERMUX_VERSION} )); then
	# Silence Message of the Day (motd)
	if [[ -f "$HOME"/../usr/etc/motd ]]; then
		mv "$HOME"/../usr/etc/motd{,.old}
	fi
	# Apply rish (Shizuku) configuration
	if [[ -d "$HOME"/.termux/rish.d && -f "$HOME"/.termux/rish.d/rish ]]; then
		(rish_exec=($(echo "$HOME"/.termux/rish.d/rish(.NxE)))
			(( 0 == ${#rish_exec} )) && chmod ug+x "$HOME"/.termux/rish.d/rish
		)
		[[ -L "$HOME"/.local/bin/rish ]] || ln -s "$HOME"/.termux/rish.d/rish "$HOME"/.local/bin/rish
		[[ "${RISH_APPLICATION_ID}" == "com.termux" ]] || export RISH_APPLICATION_ID="com.termux"
	fi
else
	return 1
fi
