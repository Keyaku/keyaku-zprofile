##############################################################################
# User login configuration
#
# TODO: Move this these configurations to a more suitable place.
##############################################################################

# Preferred editor
export EDITOR='vim'

# powerlevel10k. To customize prompt, run `p10k configure` or edit $ZDOTDIR/.p10k.zsh.
# For effective timings, this should be loaded last in the zshrc stage.
[[ "$ZSH_THEME" == "powerlevel10k" && -f "$ZDOTDIR"/.p10k.zsh ]] && _zsh_source_file "$ZDOTDIR"/.p10k.zsh
