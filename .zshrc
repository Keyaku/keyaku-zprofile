#####################################################################
#                            .zshrc
#
# File loaded 3rd && if [[ -o interactive ]]
#
# Used for setting user's interactive shell configuration
# and executing commands, will be read when starting
# as an *interactive shell*.
#####################################################################

# Required setopts for this setup to work
setopt extendedglob
setopt re_match_pcre

# Load all custom functions
export ZSH_CUSTOM="$ZDOTDIR/custom"
autoload -Uz "$ZSH_CUSTOM"/functions/{,.}**/zsource(.N) && zsource -ef

# Source interactive library functions
_zsh_source_dir "${ZDOTDIR}/lib/interactive" "lib/interactive"

# Source interactive stage
_zsh_source_dir "${ZDOTDIR}/rc" "rc"

# ZSH modules
zmodload zsh/zutil # zparseopts

# Preferred editor
export EDITOR='vim'

# powerlevel10k. To customize prompt, run `p10k configure` or edit $ZDOTDIR/.p10k.zsh.
[[ "$ZSH_THEME" == "powerlevel10k" && -f "$ZDOTDIR"/.p10k.zsh ]] && source "$ZDOTDIR"/.p10k.zsh
export ZSHRC_DONE=1
(( ${+ZDOTDIR} )) # Safety 0 return value
