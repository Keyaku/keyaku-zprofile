(( ${+commands[rust]} || ${+commands[rustup]} || ${+commands[cargo]} )) || return

[[ -d "$HOME"/.cargo ]] && xdg-migrate "$HOME"/.cargo "$CARGO_HOME"
