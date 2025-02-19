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

### SSH configuration
if (( ${+SSH_HOME} )) && [[ -d ~$USER/.ssh ]]; then
	[[ ! -d "$SSH_HOME" ]] && mkdir -p "$SSH_HOME"
	rsync -Praz ~$USER/.ssh/ "${SSH_HOME}" &>/dev/null
	[[ ! -d "$SSH_HOME/known_hosts.d" ]] && mkdir -p "$SSH_HOME/known_hosts.d"
	echo "~/.ssh copied to $SSH_HOME. You may now delete it."
fi


### Detect if this is an interactive shell
if [[ -o interactive ]]; then
	### If on Android, sync with local storage Syncthing directory
	if whatami Android; then
		## Setup function to sync between Termux and local storage. Useful when synchronizing storage files (e.g. with SyncThing)
		TERMUX_SYNC_DIR=~/storage/shared/Documents/Workspaces/Termux
		if [[ -d "$TERMUX_SYNC_DIR" ]]; then
			export TERMUX_SYNC_DIR
			function termux-rsync {
				local direction="${1:-both}"
				local path_termux=~ path_ext="$TERMUX_SYNC_DIR"
				local path_lists=$HOME/.local/src/android/Termux

				[[ -d "$path_lists" ]] || path_lists=${path_ext}/.local/src/android/Termux
				if [[ ! -d "$path_lists" ]]; then
					print_fn -e "Could not find path lists directory."
					return 1
				fi

				if [[ "$direction" == "in" || "$direction" == "both" ]]; then
					rsync -Przc --no-t --exclude-from=$path_lists/android.exclude.in.txt ${path_ext}/. ${path_termux} || return 1
				fi
				if [[ "$direction" == "out" || "$direction" == "both" ]]; then
					rsync -Przc --files-from=$path_lists/android.include.out.txt --exclude-from=$path_lists/android.exclude.out.txt ${path_termux} ${path_ext} || return 1
				fi
			}
			## Sync changes
			termux-rsync
		else
			unset TERMUX_SYNC_DIR
		fi
	else
		### Session type (X11, Wayland) configuration
		if [[ -z "${XDG_SESSION_TYPE}" ]] && command-has loginctl; then
			export XDG_SESSION_TYPE="$(loginctl show-session $(awk '/tty/ {print $1}' <(loginctl)) -p Type | awk -F= '{print $2}')"
		fi
	fi
fi
