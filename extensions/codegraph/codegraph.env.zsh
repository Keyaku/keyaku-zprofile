# CodeGraph — global install dir (versions/, current symlink, telemetry.json)
(( ${+commands[codegraph]} )) || [[ -d "$HOME/.codegraph" || -d "${XDG_DATA_HOME:-$HOME/.local/share}/codegraph" ]] || return

# Global install dir. NOT CODEGRAPH_DIR (that only renames the per-project
# .codegraph/ inside repos). The telemetry store and self-updater both read
# CODEGRAPH_INSTALL_DIR, falling back to ~/.codegraph otherwise.
export CODEGRAPH_INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/codegraph"

# Migrate a legacy ~/.codegraph and repoint the version-pinned symlinks, which
# are stored as absolute paths and would dangle after the move.
if [[ -d "$HOME/.codegraph" && ! -d "$CODEGRAPH_INSTALL_DIR" ]]; then
	xdg-migrate "$HOME/.codegraph" "$CODEGRAPH_INSTALL_DIR"
	if [[ -L "$CODEGRAPH_INSTALL_DIR/current" ]]; then
		local _cg_ver="${$(readlink "$CODEGRAPH_INSTALL_DIR/current"):t}"
		ln -sfn "$CODEGRAPH_INSTALL_DIR/versions/$_cg_ver" "$CODEGRAPH_INSTALL_DIR/current"
		ln -sfn "$CODEGRAPH_INSTALL_DIR/versions/$_cg_ver/bin/codegraph" "$HOME/.local/bin/codegraph"
	fi
fi
