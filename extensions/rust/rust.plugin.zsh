(( ${(v)#commands[(I)rust|rustc]} )) || [[ -d $HOME/.cargo ]] || return

export CARGO_HOME="$XDG_DATA_HOME"/cargo
[[ -d "$HOME"/.cargo ]] && xdg-migrate "$HOME"/.cargo "$CARGO_HOME"
