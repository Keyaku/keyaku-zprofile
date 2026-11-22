(( ${+commands[pymobiledevice3]} )) || return

# pymobiledevice3 hardcodes ~/.pymobiledevice3 (pairing records, downloaded
# developer disk images) with no env override, so keep the data under XDG and
# leave a symlink for it to follow.
if [[ -d "$HOME"/.pymobiledevice3 && ! -L "$HOME"/.pymobiledevice3 ]]; then
	xdg-migrate -a -s "$HOME"/.pymobiledevice3 "$XDG_DATA_HOME"/pymobiledevice3
fi
