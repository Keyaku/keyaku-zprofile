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

_zsh_source_dir "${ZDOTDIR}/extensions" "extensions" '*/*.(plugin|ext).zsh' ':zprofile:extensions'

# ============================================================================
# Themes
# ============================================================================

### Print fetch (login shells on a terminal only)
if (( EUID != 0 )) && [[ -o login && -t 1 ]]; then
	local fetch="fastfetch"
	local fetch_warned="$ZSH_CACHE_HOME/.fetch_warned"
	if (( ${+commands[$fetch]} )); then
		$fetch
	elif [[ ! -f "$fetch_warned" ]]; then
		print -u2 -f '%s\n' "Info: '$fetch' is not installed." "This message will only show once."
		touch "$fetch_warned"
	fi
fi

# Pick powerlevel10k: the vendored submodule (loaded by OMZ as ZSH_THEME) unless
# it's disabled or missing, then a distro-installed copy, which OMZ can't find
# under its theme dirs, so ZPROFILE_P10K_THEME has 90-user.zsh source it instead.
# Root only takes the distro copy once it has a .p10k.zsh, so it never lands in
# the configuration wizard, and a ZSH_THEME the user set (e.g. in
# settings.local.zsh) wins over it. With neither, 21-omz-config.zsh picks
# robbyrussell.
typeset -g ZPROFILE_P10K_THEME=
if _zsubmodule_enabled powerlevel10k && [[ -e "${ZSH_CUSTOM}/themes/powerlevel10k.zsh-theme" ]]; then
	ZSH_THEME="powerlevel10k"
elif [[ -z "$ZSH_THEME" ]] && { (( EUID != 0 )) || [[ -f "$ZDOTDIR"/.p10k.zsh ]] } \
	&& _zsubmodule_system_path powerlevel10k; then
	ZPROFILE_P10K_THEME=$REPLY
fi

if [[ "$ZSH_THEME" == powerlevel10k || -n "$ZPROFILE_P10K_THEME" ]]; then
	# Enable Powerlevel10k instant prompt. Should stay close to the top of .zshrc.
	# Initialization code that may require console input (password prompts, [y/n]
	# confirmations, etc.) must go above this block; everything else may go below.
	if ! [[ -n $ZSH_PROFILE_BENCHMARK || -n $ZSH_PROFILE_DEBUG ]] &&
	[[ "$POWERLEVEL9K_INSTANT_PROMPT" != "off" && -r "${XDG_CACHE_HOME}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
		_zsh_source_file "${XDG_CACHE_HOME}/p10k-instant-prompt-${(%):-%n}.zsh"
	fi
fi
