if whatami Android || (( ${+commands[adb]} )); then
	return
fi

# Start Shizuku on connected device (non-root)
alias shizuku-start='adb shell sh /storage/emulated/0/Android/data/moe.shizuku.privileged.api/start.sh'
