##############################################################################
# User login configuration
#
# TODO: Create a way to override this file (for user-specific configuration)
##############################################################################

# powerlevel10k. To customize prompt, run `p10k configure` or edit $ZDOTDIR/.p10k.zsh.
# For effective timings, this should be loaded last in the zshrc stage.
if [[ "$ZSH_THEME" == "powerlevel10k" && -f "$ZDOTDIR"/.p10k.zsh ]]; then
	[[ ! -f "$ZDOTDIR"/.p10k.zsh.zwc || "$ZDOTDIR"/.p10k.zsh -nt "$ZDOTDIR"/.p10k.zsh.zwc ]] \
		&& zcompile "$ZDOTDIR"/.p10k.zsh
	_zsh_source_file "$ZDOTDIR"/.p10k.zsh
fi
