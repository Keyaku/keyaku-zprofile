(( ${+commands[ccache]} )) || return

export CCACHE_DIR="$XDG_CACHE_HOME"/ccache
[[ -d "$HOME"/.ccache ]] && xdg-migrate -e CCACHE_DIR "$HOME"/.ccache "$CCACHE_DIR"
