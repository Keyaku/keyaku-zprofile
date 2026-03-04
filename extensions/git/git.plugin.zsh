(( ${+commands[git]} )) || return

# Check if sshCommand is in gitconfig
(GIT_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/git/config"
	[[ ! -f "$GIT_CONFIG" ]] && {
		mkdir -p "${GIT_CONFIG:h}"
		touch "$GIT_CONFIG"
	}
	# Set sshCommand if not set in gitconfig
	sshCommand=$(git config --global core.sshCommand)
	[[ ! $sshCommand =~ ^ssh ]] && {
		git config --global core.sshCommand "ssh -F ${SSH_HOME:-$HOME/.ssh}/config"
	}
)
