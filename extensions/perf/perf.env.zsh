(( ${+commands[perf]} )) || return

# perf keeps its build-id cache in ~/.debug unless PERF_BUILDID_DIR says otherwise
export PERF_BUILDID_DIR="$XDG_CACHE_HOME"/perf/debug
[[ -d "$HOME"/.debug && ! -L "$HOME"/.debug ]] && xdg-migrate -e PERF_BUILDID_DIR "$HOME"/.debug "$PERF_BUILDID_DIR"
