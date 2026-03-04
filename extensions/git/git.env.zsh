(( ${+commands[git]} )) || return

# Set and create GIT_HOME directory
export GIT_HOME=$HOME/.local/git
[[ -d "$GIT_HOME" ]] || mkdir -p "$GIT_HOME"
