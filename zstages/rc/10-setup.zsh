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
