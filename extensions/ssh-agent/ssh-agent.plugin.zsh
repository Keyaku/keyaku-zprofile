# ssh-agent.service deployment — ensure the user unit is symlinked from the repo
# into $XDG_CONFIG_HOME/systemd/user. Besides starting the agent, the unit also
# publishes SSH_AUTH_SOCK into the systemd/D-Bus session environment so that
# GUI/Flatpak apps (e.g. VSCodium's Remote-SSH) inherit it without per-app hacks.
# The repo copy is the source of truth; a displaced real file is kept as .bak.

(( EUID == 0 )) && return
has_user_systemd || return

() {
	local src="${ZDOTDIR}/conf/home/systemd/user/ssh-agent.service"
	local dst="${XDG_CONFIG_HOME:-$HOME/.local/config}/systemd/user/ssh-agent.service"

	[[ -f "$src" ]] || return
	[[ "${dst:A}" == "${src:A}" ]] && return   # already linked to the repo copy

	[[ -e "$dst" && ! -L "$dst" ]] && mv -f "$dst" "$dst.bak"
	mkdir -p "${dst:h}"
	ln -sfn "$src" "$dst"

	systemctl --user daemon-reload 2>/dev/null
	systemctl --user enable ssh-agent.service 2>/dev/null
	# A running agent keeps the old definition until restarted; don't wipe loaded
	# keys mid-session — the export takes effect on next restart or login.
	print_fn -i "Linked ssh-agent.service from repo. To apply now: systemctl --user restart ssh-agent.service"
}

if [[ -z "${SSH_AUTH_SOCK}" && -S "${XDG_RUNTIME_DIR}/ssh-agent.socket" ]]; then
	export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"
fi
