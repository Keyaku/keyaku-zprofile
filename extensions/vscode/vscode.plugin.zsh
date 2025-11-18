### VScode (Flatpak)
if (( ${(v)#commands[(I)com.visualstudio.code|com.vscodium.codium]} )); then
	for _vscode in ${(k)commands[(I)com.visualstudio.code|com.vscodium.codium]}; do
		# Point Flatpak's .ssh config to user's config
		(_vscode_dir="$HOME"/.var/app/$_vscode
			_ssh_dir="$_vscode_dir"/.ssh
			_ssh_configfile="$_ssh_dir"/config
			# Prepare ssh_config
			if [[ ! -f "$_ssh_configfile" ]] || ! \grep -q "Include ${SSH_HOME:-$HOME/.ssh}/config.d" "$_ssh_configfile"; then
				[[ -d "$_ssh_dir" ]] || mkdir -p "$_ssh_dir"
				echo "Include ${SSH_HOME:-$HOME/.ssh}/config.d/*" >> "$_ssh_configfile"
			fi
			# Prepare ssh link
			if [[ ! -L "$_vscode_dir/config/ssh" ]]; then
				ln -s "${SSH_HOME:-$HOME/.ssh}" "$_vscode_dir/config/ssh"
			fi
		)
	done
	unset _vscode

	# Sets VScode Flatpak's overrides
	function vscode-flatpak-overrides {
		local -i retval=0
		local -r flatpak_app="${commands[(i)com.visualstudio.code|com.vscodium.codium]}"

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
				retval+=$?
			fi
		done

		# Setup overrides
		local VSCODE_OVERRIDES_FILE="${FLATPAK_ENV[USER_DIR]:-$XDG_DATA_HOME/flatpak}/overrides/$flatpak_app"

		# Setup environment variables
		local -A VSCODE_ENVVARS=(
			[HOST_HOME]="$HOME"
			[HOME]="$VSCODE_HOME"
		)

		# Add .NET path
		(( ${+DOTNET_ROOT} )) && VSCODE_ENVVARS[DOTNET_ROOT]="$DOTNET_ROOT"

		# Add Sonarlint path
		if "$flatpak_app" --list-extensions 2>/dev/null | \grep -q "sonarlint"; then
			VSCODE_ENVVARS[SONARLINT_USER_HOME]="${XDG_DATA_HOME}/sonarlint"
		fi

		local vs_envkey vs_envval
		for vs_envkey vs_envval in ${(@kv)VSCODE_ENVVARS}; do
			if ! \grep -q "^$vs_envkey=$vs_envval\$" "${VSCODE_OVERRIDES_FILE}"; then
				flatpak --user override "$flatpak_app" --env="$vs_envkey=$vs_envval"
				retval+=$?
			fi
		done

		# Setup session bus
		local -a VSCODE_DBUS_TALK=(
		)
		# Use KDE wallet in case of KDE Plasma
		if (( ${+commands[plasmashell]} )) && [[ "$XDG_SESSION_DESKTOP" == KDE ]] && \
			[[ ! -z "$(dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames | grep -E 'org.kde.kwalletd\b')" ]]
		then
			VSCODE_DBUS_TALK+=("org.kde.kwalletd")
		fi

		local vs_dbus_talk
		for vs_dbus_talk in ${VSCODE_DBUS_TALK}; do
			if ! \grep -q "^$vs_dbus_talk=talk\$" "${VSCODE_OVERRIDES_FILE}"; then
				flatpak --user override $flatpak_app --talk-name="$vs_dbus_talk"
				retval+=$?
			fi
		done

		if (( ! $retval )); then
			print_fn -i "All overrides for $flatpak_app were set."
		else
			print_fn -w "Errors occured while setting overrides for $flatpak_app."
		fi
		return $retval
	}
elif (( ${+commands[code]} )); then
	: # Add config for regular VScode installation
fi
