(( ${(v)#commands[(I)cargo|rust|rustc|rustup]} )) || return

[[ -d "$HOME"/.cargo ]] && xdg-migrate "$HOME"/.cargo "$CARGO_HOME"
