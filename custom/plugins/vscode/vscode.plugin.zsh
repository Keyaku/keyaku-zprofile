### VScode (Flatpak)
if (( ${+commands[com.visualstudio.code]} )); then
	# Point Flatpak's .ssh config to user's config
	(_ssh_dir="$HOME"/.var/app/com.visualstudio.code/.ssh
	_ssh_configfile="$_ssh_dir"/config
		if [[ ! -f "$_ssh_configfile" ]] || ! \grep -Eq "Include ${SSH_HOME:-~/.ssh}/config" "$_ssh_configfile"; then
			[[ -d "$_ssh_dir" ]] || mkdir -p "$_ssh_dir"
			echo "Include ${SSH_HOME:-~/.ssh}/config" >> "$_ssh_configfile"
			echo "Include ${SSH_HOME:-~/.ssh}/config.d/*" >> "$_ssh_configfile"
		fi
	)

	# Sets VScode Flatpak's overrides
	function vscode-flatpak-overrides {
		local -r flatpak_app="com.visualstudio.code"

		# Setup symlinks
		local -r VSCODE_HOME="${FLATPAK_ENV[USER_APPDATA]:-$HOME/.var/app}/$flatpak_app"
		local -A VSCODE_SYMLINKS=(
			[.pki]="$XDG_DATA_HOME/pki"
			[.gitconfig]="$XDG_CONFIG_HOME/git/config"
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
