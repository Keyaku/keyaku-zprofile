(( ${+commands[rust]} || ${+commands[rustup]} || ${+commands[cargo]} )) || return

export CARGO_HOME="$XDG_DATA_HOME"/cargo
addpath "$CARGO_HOME"/bin

export RUSTUP_HOME="$XDG_DATA_HOME"/rustup
