(( ${+commands[git]} )) || return

# Set sshCommand if not set in gitconfig
local sshCommand=$(git config --global --get core.sshCommand)
if [[ ${sshCommand:0:3} != 'ssh' ]]; then
	git config --global core.sshCommand "ssh -F ${SSH_HOME:-$HOME/.ssh}/config"
fi
