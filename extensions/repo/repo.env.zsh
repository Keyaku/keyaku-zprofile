# Android `repo` — relocate its GPG keyring out of $HOME/.repoconfig
(( ${+commands[repo]} )) || [[ -d "$HOME/.repoconfig" || -d "${XDG_DATA_HOME:-$HOME/.local/share}/.repoconfig" ]] || return

# repo joins REPO_CONFIG_DIR with the literal ".repoconfig" (defaults to $HOME),
# then points GNUPGHOME at <dir>/.repoconfig/gnupg itself at runtime.
export REPO_CONFIG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

# Migrate a legacy ~/.repoconfig (keyring rebuilds itself if absent anyway).
if [[ -d "$HOME/.repoconfig" && ! -d "$REPO_CONFIG_DIR/.repoconfig" ]]; then
	xdg-migrate "$HOME/.repoconfig" "$REPO_CONFIG_DIR/.repoconfig"
fi
