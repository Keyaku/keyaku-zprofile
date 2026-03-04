(( ${(v)#commands[(I)cargo|rust|rustc|rustup]} )) || return

export CARGO_HOME="$XDG_DATA_HOME"/cargo
