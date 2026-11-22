##############################################################################
# compinit when Oh-My-Zsh didn't run it
##############################################################################
# With OMZ loaded (25-omz-load.zsh), `compdef` exists already and this no-ops.
# Otherwise initialise completion on the fpath set by 24-fpath.zsh. Root skips
# the insecure-directory check, since its fpath points into the repo user's
# tree; everyone else silently ignores insecure directories.

(( ${+functions[compdef]} )) && return

autoload -Uz compinit
if (( EUID == 0 )); then
	compinit -u -d "$ZSH_COMPDUMP"
else
	compinit -i -d "$ZSH_COMPDUMP"
fi
