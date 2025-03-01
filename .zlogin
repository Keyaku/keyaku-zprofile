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

### Android development
if (( ${+ANDROID_HOME} )) && [[ -d "$ANDROID_HOME/sdk" ]]; then
	# Contrary to search results, do NOT set ANDROID_SDK_ROOT
	# Pick the latest NDK version found (tests non-empty directories)
	ANDROID_NDK_HOME="$(echo "$ANDROID_HOME/sdk/ndk"/*(OnFN/[1]))"
	[[ "$ANDROID_NDK_HOME" ]] && export ANDROID_NDK_HOME || unset ANDROID_NDK_HOME

	export GRADLE_USER_HOME="$XDG_DATA_HOME"/gradle
	#export _JAVA_OPTIONS+=-Djava.util.prefs.userRoot="$XDG_CONFIG_HOME"/java

	addpath 1 "${ANDROID_HOME}/sdk/platform-tools"
fi

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

### SSH configuration
if (( ${+SSH_HOME} )) && [[ -d $HOME/.ssh ]]; then
	[[ -d "$SSH_HOME" ]] || mkdir -p "$SSH_HOME"
	rsync -Praz "$HOME"/.ssh/ "${SSH_HOME}" &>/dev/null
	[[ -d "$SSH_HOME/known_hosts.d" ]] || mkdir -p "$SSH_HOME/known_hosts.d"
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
