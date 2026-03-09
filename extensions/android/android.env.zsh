# if NOT on Android
if ! whatami Android; then
	if (( ${+commands[adb]} )) || [[ -d "${XDG_DATA_HOME}/android" ]]; then

		# Android debugging
		export ANDROID_ROOT="${XDG_DATA_HOME}/android"
		[[ -d "$ANDROID_ROOT" ]] || mkdir -p "$ANDROID_ROOT"
		export ANDROID_USER_HOME="${ANDROID_ROOT}/.android"

		if (( ${+commands[adb]} )); then
			# Start Shizuku on connected device (non-root)
			alias shizuku-start='adb shell sh /sdcard/Android/data/moe.shizuku.privileged.api/start.sh'

			# Prevent adb from using user's home directory
			alias adb="HOME=$ANDROID_ROOT ${commands[adb]}"
			alias fastboot="HOME=$ANDROID_ROOT ${commands[fastboot]}"
		fi

		# Android development. Prefer sdk/ over ndk/
		if [[ -d "${ANDROID_ROOT}"/sdk ]]; then
			# Contrary to search results, do NOT set this path as ANDROID_SDK_ROOT. Set it as ANDROID_HOME:
			export ANDROID_HOME="${ANDROID_ROOT}"/sdk
			# Pick the latest NDK version found (tests non-empty directories)
			local -a ndk_dirs=("$ANDROID_ROOT/sdk/ndk"/*(OnFN/[1]))
			if [[ -n "${ndk_dirs[1]}" ]]; then
				export ANDROID_NDK_ROOT="${ndk_dirs[1]}"
				addpath "$ANDROID_NDK_ROOT"
			fi

			export GRADLE_USER_HOME="$XDG_DATA_HOME"/gradle
			#export _JAVA_OPTIONS+=-Djava.util.prefs.userRoot="$XDG_CONFIG_HOME"/java

			# Prepend platform tools to override system installation
			addpath -p "${ANDROID_ROOT}/sdk/platform-tools"
		fi
	fi
# if actually on Android (Termux)
elif [[ -v TERMUX_VERSION && "${TERMUX__PREFIX:P}" == "/data/data/com.termux/files/usr" ]]; then
	export XDG_RUNTIME_DIR="${${:-$TERMUX__PREFIX/var/run/$UID}:P}"
fi
