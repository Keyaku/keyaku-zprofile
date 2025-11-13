#####################################################################
#                            .zlogin
#
# File loaded 4th && if [[ -o login ]]
#
# Used for executing user's commands at ending of initial progress,
# will be read when starting as a login shell.
# Typically used to autostart command line utilities.
# Should not be used to autostart graphical sessions,
# as at this point the session might contain configuration
# meant only for an interactive shell.
#####################################################################

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
	# Default Steam paths
	steam-set-paths

	# WeMod launcher
	WEMOD_HOME="${GIT_HOME:-$HOME/.local/git}/_games/wemod-launcher"
	[[ -d "$WEMOD_HOME" ]] && export WEMOD_HOME || unset WEMOD_HOME
fi


### Last execution to run if in an interactive shell
if [[ -o interactive ]]; then
	if ! whatami Android; then
		### Session type (X11, Wayland) configuration
		if [[ -z "${XDG_SESSION_TYPE}" ]] && command-has loginctl; then
			export XDG_SESSION_TYPE="$(loginctl show-session $(awk '/tty/ {print $1}' <(loginctl)) -p Type | awk -F= '{print $2}')"
		fi
	fi
fi
