(( ${+commands[git]} )) || return

# Set sshCommand if not set in gitconfig. Reading the global config files
# directly skips a `git config` fork on every shell once the key is there.
() {
	local f
	for f in "${XDG_CONFIG_HOME:-$HOME/.config}/git/config" "$HOME/.gitconfig"; do
		[[ -f "$f" && "${(L)$(<$f)}" == *sshcommand*=*ssh* ]] && return
	done
	local sshCommand=$(git config --global --get core.sshCommand)
	if [[ ${sshCommand:0:3} != 'ssh' ]]; then
		git config --global core.sshCommand "ssh -F ${SSH_HOME:-$HOME/.ssh}/config"
	fi
}
