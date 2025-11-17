(( ${+commands[gpg-agent]} )) || return

[[ -z "$GNUPGHOME" || "$GNUPGHOME" != "${XDG_DATA_HOME:-$HOME/.local/share}"/gnupg ]] && \
	export GNUPGHOME="${XDG_DATA_HOME:-$HOME/.local/share}"/gnupg
[[ -d "$GNUPGHOME" ]] || mkdir -p "$GNUPGHOME"

if [[ ! -f "$GNUPGHOME/gpg-agent.conf" ]] || ! \grep -q 'pinentry-program' "$GNUPGHOME/gpg-agent.conf"; then
	echo "pinentry-program /usr/bin/pinentry" >> "$GNUPGHOME/gpg-agent.conf"
fi

# Start gpg-agent with systemd
# FIXME: This is currently not enough to work with Flatpak VSCode. Launching Kleopatra seems to address it, but I need to resolve this here.
if has_systemd && ! systemctl --user -q status gpg-agent &>/dev/null; then
	systemctl --user -q enable --now gpg-agent
fi

# Load available plugin from ohmyzsh
# FIXME: add gpg-agent to `plugins` array rather than sourcing it directly
[[ -f "$ZSH/plugins/${0:h:t}/${0:t}" ]] && source "$ZSH/plugins/${0:h:t}/${0:t}"
