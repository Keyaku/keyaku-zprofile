### VScode (Flatpak)
local -A vsc_flatpaks=(${(kv)commands[(I)com.visualstudio.code|com.vscodium.codium]})

if (( ${(v)#vsc_flatpaks} )); then
	local _vscode _vscode_dir
	for _vscode in ${(k)vsc_flatpaks}; do
		_vscode_dir="$HOME"/.var/app/$_vscode
		# Point Flatpak's .ssh config to user's config
		{
			local _ssh_dir="$_vscode_dir"/.ssh
			local _ssh_configfile="$_ssh_dir"/config
			# Prepare ssh_config
			if [[ ! -f "$_ssh_configfile" ]] || ! \grep -q "Include ${SSH_HOME:-$HOME/.ssh}/config.d" "$_ssh_configfile"; then
				[[ -d "$_ssh_dir" ]] || mkdir -p "$_ssh_dir"
				echo "Include ${SSH_HOME:-$HOME/.ssh}/config.d/*" >> "$_ssh_configfile"
			fi
			# Prepare ssh link
			if [[ ! -L "$_vscode_dir/config/ssh" ]]; then
				ln -s "${SSH_HOME:-$HOME/.ssh}" "$_vscode_dir/config/ssh"
			fi
		} &|

		# Use VSCode's java binary if java isn't available
		if (( ! ${+commands[java]} )); then
			local _java_path="$_vscode_dir"/data/codium/extensions/redhat.java*/jre/*/bin/java(.N[1])
			if [[ -e "${_java_path}" ]]; then
				export JAVA_HOME="${_java_path:h:h}"
				addpath "$JAVA_HOME/bin"
			fi
		fi
	done

elif (( ${+commands[code]} )); then
	: # Add config for regular VScode installation
fi
