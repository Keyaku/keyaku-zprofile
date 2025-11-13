[[ -d "$HOME"/.lein || -d "$XDG_DATA_HOME"/lein ]] || return

export LEIN_HOME="$XDG_DATA_HOME"/lein
[[ -d "$HOME"/.lein ]] && xdg-migrate "$HOME"/.lein "$LEIN_HOME"
