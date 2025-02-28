#######################################
### Microsoft
#######################################

if [[ -o login ]]; then

### .NET
# Use Homebrew's .NET installation
if (( ${+HOMEBREW_PREFIX} )) && [[ -d "$HOMEBREW_CELLAR/dotnet" ]]; then
	export DOTNET_ROOT="${HOMEBREW_PREFIX}/opt/dotnet/libexec"
# Use user installation
elif [[ "${XDG_DATA_HOME}/dotnet" ]]; then
	export DOTNET_ROOT="${XDG_DATA_HOME}/dotnet"
else
	unset DOTNET_ROOT
fi

if (( ${+DOTNET_ROOT} )); then
	export DOTNET_INSTALL_DIR="${DOTNET_ROOT}"
	[[ -d "$DOTNET_INSTALL_DIR/.dotnet/tools" ]] && addpath "$DOTNET_INSTALL_DIR/.dotnet/tools"
	export DOTNET_CLI_HOME="${DOTNET_ROOT}"
	export DOTNET_CLI_TELEMETRY_OPTOUT=true
	export NUGET_PACKAGES="${XDG_CACHE_HOME}/NuGetPackages"
fi

### VScode (Flatpak)
if (( ${+commands[com.visualstudio.code]} )); then
	# Sets VScode Flatpak's overrides
	function vscode-flatpak-overrides {
		local -r flatpak_app="com.visualstudio.code"

		# Setup symlinks
		local -r VSCODE_HOME="${FLATPAK_ENV[USER_APPDATA]:-$HOME/.var/app}/$flatpak_app"
		local -A VSCODE_SYMLINKS=(
			[.pki]="$XDG_DATA_HOME/pki"
			[.gitconfig]="$XDG_CONFIG_HOME/git/config"
			[config/ssh]="${SSH_HOME:-$XDG_CONFIG_HOME/ssh}"
		)

		local vs_target vs_src
		for vs_target vs_src in ${(@kv)VSCODE_SYMLINKS}; do
			if [[ -e "$vs_src" ]] && [[ ! -L "${VSCODE_HOME}/$vs_target" ]]; then
				[[ -e "${VSCODE_HOME}/$vs_target" ]] && rm -rf "${VSCODE_HOME}/$vs_target"
				ln -s "$vs_src" "${VSCODE_HOME}/$vs_target"
			fi
		done

		# Setup overrides
		local VSCODE_OVERRIDES_FILE="${FLATPAK_ENV[USER_DIR]:-$XDG_DATA_HOME/flatpak}/overrides/$flatpak_app"

		# Setup environment variables
		local -A VSCODE_ENVVARS=(
			[HOST_HOME]="$HOME"
			[HOME]="$VSCODE_HOME"
			[ELECTRON_OZONE_PLATFORM_HINT]=auto
			[ELECTRON_TRASH]=trash
			[TRASHDIR]="${XDG_DATA_HOME}/Trash"
			[SONARLINT_USER_HOME]="${XDG_DATA_HOME}/sonarlint"
		)
		(( ${+DOTNET_ROOT} )) && VSCODE_ENVVARS[DOTNET_ROOT]="$DOTNET_ROOT"

		local vs_envkey vs_envval
		for vs_envkey vs_envval in ${(@kv)VSCODE_ENVVARS}; do
			if ! \grep -q "^$vs_envkey=$vs_envval\$" "${VSCODE_OVERRIDES_FILE}"; then
				flatpak --user override $flatpak_app --env="$vs_envkey=$vs_envval"
			fi
		done

		# Setup session bus
		local -a VSCODE_DBUS_TALK=(
			org.kde.kwalletd
		)

		local vs_dbus_talk
		for vs_dbus_talk in ${VSCODE_DBUS_TALK}; do
			if ! \grep -q "^$vs_dbus_talk=talk\$" "${VSCODE_OVERRIDES_FILE}"; then
				flatpak --user override $flatpak_app --talk-name="$vs_dbus_talk"
			fi
		done
	}
fi

fi
