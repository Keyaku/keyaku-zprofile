# if NOT on Android
if ! whatami Android; then
	if (( ${+commands[adb]} )) || [[ -d "${XDG_DATA_HOME}/android" ]]; then
		# Start Shizuku on connected device (non-root)
		alias shizuku-start='adb shell sh /sdcard/Android/data/moe.shizuku.privileged.api/start.sh'

		# Android debugging
		export ANDROID_ROOT="${XDG_DATA_HOME}/android"
		[[ -d "$ANDROID_ROOT" ]] || mkdir -p "$ANDROID_ROOT"
		export ANDROID_USER_HOME="${ANDROID_ROOT}/.android"

		if (( ${+commands[adb]} )); then
			# Prevent adb from using user's home directory
			alias adb="HOME=$ANDROID_ROOT ${commands[adb]}"
			alias fastboot="HOME=$ANDROID_ROOT ${commands[fastboot]}"
		fi

		# Android development. Prefer sdk/ over ndk/
		if [[ -d "${ANDROID_ROOT}"/sdk ]]; then
			# Contrary to search results, do NOT set this path as ANDROID_SDK_ROOT. Set it as ANDROID_HOME:
			export ANDROID_HOME="${ANDROID_ROOT}"/sdk
			# Pick the latest NDK version found (tests non-empty directories)
			ANDROID_NDK_ROOT="$(echo "$ANDROID_ROOT/sdk/ndk"/*(OnFN/[1]))"
			if [[ "$ANDROID_NDK_ROOT" ]]; then
				export ANDROID_NDK_ROOT
				addpath "$ANDROID_NDK_ROOT"
			else
				unset ANDROID_NDK_ROOT
			fi

			export GRADLE_USER_HOME="$XDG_DATA_HOME"/gradle
			#export _JAVA_OPTIONS+=-Djava.util.prefs.userRoot="$XDG_CONFIG_HOME"/java

			# Prepend platform tools to override system installation
			addpath -p "${ANDROID_ROOT}/sdk/platform-tools"
		fi
	fi
# if actually on Android (Termux)
elif (( ${+TERMUX_VERSION} )); then
	# Silence Message of the Day (motd)
	if [[ -f "$HOME"/../usr/etc/motd ]]; then
		mv "$HOME"/../usr/etc/motd{,.old}
	fi
	# Apply rish (Shizuku) configuration
	if [[ -d "$HOME"/.termux/rish.d && -f "$HOME"/.termux/rish.d/rish ]]; then
		(rish_exec=($(echo "$HOME"/.termux/rish.d/rish(.NxE)))
			(( 0 == ${#rish_exec} )) && chmod ug+x "$HOME"/.termux/rish.d/rish
		)
		if [[ ! -L "$HOME"/.local/bin/rish ]]; then
			rm -f "$HOME"/.local/bin/rish
			ln -s "$HOME"/.termux/rish.d/rish "$HOME"/.local/bin/rish
		fi
		[[ "${RISH_APPLICATION_ID}" == "com.termux" ]] || export RISH_APPLICATION_ID="com.termux"
	fi
else
	return 1
fi
