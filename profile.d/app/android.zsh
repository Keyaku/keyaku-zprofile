# if NOT on Android
if ! whatami Android; then
	if (( ${+commands[adb]} )); then
		# Start Shizuku on connected device (non-root)
		alias shizuku-start='adb shell sh /storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh'
	fi
# if actually on Android (Termux)
elif [[ -d "$HOME/.termux" ]]; then
	alias pkg-all='pkg update && pkg upgrade -y'
fi
