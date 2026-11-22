### VScode (Flatpak)
local -A vsc_flatpaks=(${(kv)commands[(I)com.visualstudio.code|com.vscodium.codium]})

if (( ${(v)#vsc_flatpaks} )); then
	local _vscode _vscode_dir
	for _vscode in ${(k)vsc_flatpaks}; do
		_vscode_dir="$HOME"/.var/app/$_vscode
		# Point the Flatpak's .ssh config to the user's config. Fork-free checks,
		# so this runs in the foreground and can say what it changed (once).
		{
			local _ssh_dir="$_vscode_dir"/.ssh
			local _ssh_configfile="$_ssh_dir"/config
			local _ssh_include="Include ${SSH_HOME:-$HOME/.ssh}/config.d/*"
			# Prepare ssh_config
			if [[ ! -f "$_ssh_configfile" || "$(<"$_ssh_configfile")" != *"Include ${SSH_HOME:-$HOME/.ssh}/config.d"* ]]; then
				[[ -d "$_ssh_dir" ]] || mkdir -p "$_ssh_dir"
				print -r -- "$_ssh_include" >> "$_ssh_configfile"
				print_fn -i "Added '$_ssh_include' to $_ssh_configfile so $_vscode sees your SSH hosts (remove that line to undo)"
			fi
			# Prepare ssh link
			if [[ ! -L "$_vscode_dir/config/ssh" ]]; then
				ln -s "${SSH_HOME:-$HOME/.ssh}" "$_vscode_dir/config/ssh"
				print_fn -i "Linked $_vscode_dir/config/ssh to ${SSH_HOME:-$HOME/.ssh} (remove the link to undo)"
			fi
		}

		# Use VSCode's java binary if java isn't available
		if (( ! ${+commands[java]} )); then
			local _java_path=("$_vscode_dir"/data/codium/extensions/redhat.java*/jre/*/bin/java(.N[1]))
			if [[ -e "${_java_path[1]}" ]]; then
				export JAVA_HOME="${_java_path[1]:h:h}"
				addpath "$JAVA_HOME/bin"
				# Force reload java plugin, envvars, etc.
				# TODO: This is a hack; probably use a hook or an array instead.
				_zsh_source_dir ${ZDOTDIR}/extensions/java "extensions/java" "*.zsh" ":zprofile:extensions"
			fi
		fi
	done

elif (( ${+commands[code]} )); then
	: # Add config for regular VScode installation
fi
