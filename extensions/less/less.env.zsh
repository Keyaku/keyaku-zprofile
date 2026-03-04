# Less (is more)
(( ${+commands[less]} )) || return

export LESSHISTFILE="${XDG_CACHE_HOME}/less/history"
export LESS=' -R '
