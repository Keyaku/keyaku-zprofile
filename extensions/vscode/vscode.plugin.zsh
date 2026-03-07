### VScode (Flatpak)
if (( ${(v)#commands[(I)com.visualstudio.code|com.vscodium.codium]} )); then
	for _vscode in ${(k)commands[(I)com.visualstudio.code|com.vscodium.codium]}; do
		_vscode_dir="$HOME"/.var/app/$_vscode
		# Point Flatpak's .ssh config to user's config
		(
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
		# Use VSCode's java binary if java isn't available
		if (( ! ${+commands[java]} )); then
			_java_path="$_vscode_dir"/data/codium/extensions/redhat.java*/jre/*/bin/java(.N[1])
			if [[ -e "${_java_path}" ]]; then
				export JAVA_HOME="${_java_path:h:h}"
				addpath "$JAVA_HOME/bin"
			fi
			unset _java_path
		fi
	done
	unset _vscode_dir _vscode

elif (( ${+commands[code]} )); then
	: # Add config for regular VScode installation
fi
