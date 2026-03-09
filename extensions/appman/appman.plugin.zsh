(( ${+commands[appman]} )) || return

[[ -d $HOME/.local/app/appman ]] && export SANDBOXDIR=$HOME/.local/app/appman/sandboxes
