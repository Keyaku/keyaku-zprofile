# Set CODEX_HOME when Codex is installed OR its XDG config already exists — the
# latter keeps the var in the session env even before codex is on $PATH and
# after the ~/.codex symlink is gone, without polluting systems lacking both.
(( ${+commands[codex]} )) || [[ -d ${XDG_CONFIG_HOME}/codex ]] || return
export CODEX_HOME=${XDG_CONFIG_HOME}/codex
[[ -d $HOME/.codex && ! -L $HOME/.codex ]] && xdg-migrate $HOME/.codex "$CODEX_HOME"
