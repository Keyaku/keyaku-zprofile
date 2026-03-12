# FIXME: This should be either OMZ or a series of scripts/code with the following requirements:
# * Sets up zsh prompt
# * Loads a theme
# * Loads plugins
# * Fires up compinit, compdef, etc.

# For now, this file is a placeholder until omz can be easily replaced by the user.

# ============================================================================
# Load extensions
# ============================================================================
# Similar to plugins, but should be loaded before any plugin and/or
# plugin loader (like OMZ).

_zsh_source_dir "${ZDOTDIR}/extensions" "extensions" '*/*.(plugin|ext).zsh'

# ============================================================================
# Themes
# ============================================================================

# Check for p10k; if non-existent, use robbyrussel
if [[ -L "${ZSH_CUSTOM}/themes/powerlevel10k.zsh-theme" ]]; then
	ZSH_THEME="powerlevel10k"

	# Enable Powerlevel10k instant prompt. Should stay close to the top of .zshrc.
	# Initialization code that may require console input (password prompts, [y/n]
	# confirmations, etc.) must go above this block; everything else may go below.
	if [[ "$POWERLEVEL9K_INSTANT_PROMPT" != "off" && -r "${ZSH_CACHE_HOME}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
		_zsh_source_file "${ZSH_CACHE_HOME}/p10k-instant-prompt-${(%):-%n}.zsh"
	fi
fi
