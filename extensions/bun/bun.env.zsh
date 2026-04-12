(( ${+commands[bun]} )) || return

[[ -d "$XDG_CACHE_HOME"/.bun/bin ]] && addpath "$XDG_CACHE_HOME"/.bun/bin
