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

	# Function to synchronize changes between local storage and Termux storage
	function termux-rsync {
		local direction="${1:-both}"
		local path_termux=~ path_ext="$TERMUX_SYNC_DIR"
		local path_lists=$HOME/.local/src/android/Termux

		[[ -d "$path_lists" ]] || path_lists=${path_ext}/.local/src/android/Termux
		if [[ ! -d "$path_lists" ]]; then
			print_fn -e "Could not find path lists directory."
			return 1
		fi

		if [[ "$direction" == "in" || "$direction" == "both" ]]; then
			rsync -Przc --no-t --exclude-from=$path_lists/android.exclude.in.txt ${path_ext}/. ${path_termux} || return 1
		fi
		if [[ "$direction" == "out" || "$direction" == "both" ]]; then
			rsync -Przc --files-from=$path_lists/android.include.out.txt --exclude-from=$path_lists/android.exclude.out.txt ${path_termux} ${path_ext} || return 1
		fi
	}
else
	return 1
fi
