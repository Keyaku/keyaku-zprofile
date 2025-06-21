# if NOT on Android
if ! whatami Android; then
	(( ${+commands[adb]} )) || return
	# Start Shizuku on connected device (non-root)
	alias shizuku-start='adb shell sh /storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh'
# if actually on Android (Termux)
elif (( ${+TERMUX_VERSION} )); then
	# Silence Message of the Day (motd)
	if [[ -f "$HOME"/../usr/etc/motd ]]; then
		mv "$HOME"/../usr/etc/motd{,.old}
	fi
else
	return 1
fi
