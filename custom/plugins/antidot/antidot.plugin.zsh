# Do nothing if not installed
(( ${+commands[antidot]} )) || return

# If the completion file doesn't exist yet, we need to autoload it and
# bind it. Otherwise, compinit will have already done that.
if [[ ! -f "$ZSH_CACHE_DIR/completions/_antidot" ]]; then
	typeset -gA _comps
	autoload -Uz _antidot
	_comps[antidot]=_antidot
fi

antidot completion zsh >| "$ZSH_CACHE_DIR/completions/_antidot" &|

# Source antidot files
for f_antidot in "${XDG_DATA_HOME}"/antidot/{env,alias}.sh; do
	[[ -f "${f_antidot}" ]] && source "${f_antidot}"
done
