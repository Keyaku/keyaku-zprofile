(( ${+commands[metapac]} )) || return

# If the completion file doesn't exist yet, we need to autoload it and
# bind it to `metapac`. Otherwise, compinit will have already done that.
if [[ ! -f "$ZSH_CACHE_DIR/completions/_metapac" ]]; then
	typeset -g -A _comps
	autoload -Uz _metapac
	_comps[metapac]=_metapac
fi

# Generate and load metapac completion
metapac completions --shell zsh >! "$ZSH_CACHE_DIR/completions/_metapac" &|
