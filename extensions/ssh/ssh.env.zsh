(( ${+commands[ssh]} )) || return

export SSH_HOME=${XDG_CONFIG_HOME}/ssh
[[ -d $HOME/.ssh ]] && xdg-migrate $HOME/.ssh "${SSH_HOME}"
