##############################################################################
# User login configuration
#
# TODO: Create a way to override this file (for user-specific configuration)
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
[[ -f "$XDG_DATA_HOME"/pyvenv/pyvenv.cfg ]] && . "$XDG_DATA_HOME/pyvenv/bin/activate"

### Steam
if (( ${+commands[steam]} )); then
	# WeMod launcher
	WEMOD_HOME="${GIT_HOME:-$HOME/.local/git}/_games/wemod-launcher"
	[[ -d "$WEMOD_HOME" ]] && export WEMOD_HOME || unset WEMOD_HOME
fi
