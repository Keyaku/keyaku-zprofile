(( ${+commands[claude]} )) || return

export CLAUDE_CONFIG_DIR=${XDG_CONFIG_HOME}/claude
[[ -d $HOME/.claude && ! -L $HOME/.claude ]] && xdg-migrate $HOME/.claude "${CLAUDE_CONFIG_DIR}"
