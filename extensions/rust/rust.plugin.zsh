(( ${+commands[rust]} || ${+commands[rustup]} || ${+commands[cargo]} )) || return

[[ -d "$HOME"/.cargo ]] && xdg-migrate -e CARGO_HOME "$HOME"/.cargo "$CARGO_HOME"
