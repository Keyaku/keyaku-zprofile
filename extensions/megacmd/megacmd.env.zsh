(( ${+commands[mega-cmd]} )) || return

# MEGAcmd honors nothing but $HOME for its state/cache dir (upstream megacmd#966 — not configurable),
# so it can't be redirected with an env var.
# Instead migrate the dir under XDG and leave a symlink, so the persistent
# mega-cmd-server still resolves it via $HOME.
# Skip while the server is live to avoid pulling its state DBs out from under it mid-run.
if [[ -d "$HOME"/.megaCmd && ! -L "$HOME"/.megaCmd ]] && ! pgrep -x mega-cmd-server &>/dev/null; then
	xdg-migrate -s "$HOME"/.megaCmd "$XDG_DATA_HOME"/megaCmd
fi
