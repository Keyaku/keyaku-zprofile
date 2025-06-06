(( ${+commands[git]} )) || return

# Load available plugin from ohmyzsh (including completion)
[[ -f "$ZSH/plugins/${0:h:t}/${0:t}" ]] && source "$ZSH/plugins/${0:h:t}/${0:t}"

# Check if sshCommand is in gitconfig
GIT_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/git/config"
[[ ! -f "$GIT_CONFIG" ]] && {
	mkdir -p "${GIT_CONFIG:h}"
	touch "$GIT_CONFIG"
}

unset GIT_CONFIG
