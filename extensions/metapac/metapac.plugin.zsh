(( ${+commands[metapac]} )) || return

# Generate completions
if [[ ! -f "$ZSH_CACHE_DIR/completions/_metapac" ]]; then
	typeset -g -A _comps
	autoload -Uz _metapac
	_comps[metapac]=_metapac
fi

{
	metapac completions --shell zsh | tee "$ZSH_CACHE_DIR/completions/_metapac" > /dev/null
} &|
