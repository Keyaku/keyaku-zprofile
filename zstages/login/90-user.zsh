##############################################################################
# User login configuration
#
# TODO: Move this these configurations to a more suitable place.
##############################################################################

### Docker configuration
if (( ${+commands[docker]} )) && (( ! ${+commands[podman]} )); then
	docker-set-env
fi

### Homebrew
if (( ${+commands[brew]} )); then
	export HOMEBREW_NO_ANALYTICS=1
	export HOMEBREW_NO_ENV_HINTS=1
fi

### Python
if [[ -f "$XDG_DATA_HOME"/pyvenv/pyvenv.cfg ]]; then
	vrun "$XDG_DATA_HOME"/pyvenv &>/dev/null
fi

### Steam
if (( ${+commands[steam]} )); then
	# WeMod launcher
	WEMOD_HOME="${GIT_HOME:-$HOME/.local/git}/_games/wemod-launcher"
	[[ -d "$WEMOD_HOME" ]] && export WEMOD_HOME || unset WEMOD_HOME
fi
