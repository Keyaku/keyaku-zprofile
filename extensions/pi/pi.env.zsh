# pi (coding agent) defaults to ~/.pi/agent; PI_CODING_AGENT_DIR moves it. Its
# launcher may be a broken link once ~/.pi is gone, so don't guard on the command.
[[ -d "$XDG_CONFIG_HOME"/pi || -e "$HOME"/.pi ]] || return

export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME"/pi/agent
if [[ -d "$HOME"/.pi && ! -L "$HOME"/.pi ]]; then
	xdg-migrate -e PI_CODING_AGENT_DIR "$HOME"/.pi "$XDG_CONFIG_HOME"/pi
fi

# A ~/.pi symlink into the XDG dir is no longer needed, but pi's installer points
# ~/.local/bin/pi through it, so repoint that link first. Interactive shells only.
if [[ -o interactive && -L "$HOME"/.pi && ${${:-$HOME/.pi}:A} == ${${:-$XDG_CONFIG_HOME/pi}:A} ]]; then
	() {
		local launcher="$HOME"/.local/bin/pi
		if [[ -L "$launcher" && "$(readlink "$launcher")" == *.pi/* ]]; then
			ln -sfn "$PI_CODING_AGENT_DIR"/bin/pi "$launcher" || return
		fi
		rm "$HOME"/.pi && print_fn -i "Removed the ~/.pi symlink (pi reads PI_CODING_AGENT_DIR=$PI_CODING_AGENT_DIR); undo: ln -s $XDG_CONFIG_HOME/pi ~/.pi"
	}
fi
