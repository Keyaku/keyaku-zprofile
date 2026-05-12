# (( ${+commands[codex]} )) || return
[[ -d $HOME/.codex ]] || return

export CODEX_HOME=${XDG_CONFIG_HOME}/codex
[[ -d $HOME/.codex && ! -L $HOME/.codex ]] && xdg-migrate -l $HOME/.codex "${CODEX_HOME}"
