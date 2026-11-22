##############################################################################
# powerlevel10k theme and configuration
##############################################################################

# powerlevel10k. To customize prompt, run `p10k configure` or edit $ZDOTDIR/.p10k.zsh.
# For effective timings, this should be loaded last in the zshrc stage.
# A distro-installed copy (see 10-setup.zsh) is sourced here, before its config,
# and so is the vendored one when OMZ isn't there to load it as ZSH_THEME.
if [[ -n "$ZPROFILE_P10K_THEME" ]]; then
	_zsh_source_file "$ZPROFILE_P10K_THEME"
elif [[ "$ZSH_THEME" == "powerlevel10k" && -z "$ZSH" ]]; then
	_zsh_source_file "$ZSH_CUSTOM/themes/powerlevel10k.zsh-theme"
fi
if [[ "$ZSH_THEME" == "powerlevel10k" || -n "$ZPROFILE_P10K_THEME" ]] && [[ -f "$ZDOTDIR"/.p10k.zsh ]]; then
	[[ ! -f "$ZDOTDIR"/.p10k.zsh.zwc || "$ZDOTDIR"/.p10k.zsh -nt "$ZDOTDIR"/.p10k.zsh.zwc ]] \
		&& zcompile "$ZDOTDIR"/.p10k.zsh
	_zsh_source_file "$ZDOTDIR"/.p10k.zsh
fi
