(( ${+commands[gpg-agent]} )) || return

[[ -z "$GNUPGHOME" || "$GNUPGHOME" != "${XDG_DATA_HOME:-$HOME/.local/share}"/gnupg ]] && \
	export GNUPGHOME="${XDG_DATA_HOME:-$HOME/.local/share}"/gnupg
[[ -d "$GNUPGHOME" ]] || mkdir -p "$GNUPGHOME"

if [[ ! -f "$GNUPGHOME/gpg-agent.conf" ]] || ! \grep -q 'pinentry-program' "$GNUPGHOME/gpg-agent.conf"; then
	echo "pinentry-program /usr/bin/pinentry" >> "$GNUPGHOME/gpg-agent.conf"
fi

# Start gpg-agent with systemd
if has_systemd && ! systemctl --user -q is-active gpg-agent.socket; then
	systemctl --user -q start gpg-agent.socket
fi

# Load available plugin from ohmyzsh
# FIXME: add gpg-agent to `plugins` array rather than sourcing it directly
[[ -f "$ZSH/plugins/${0:h:t}/${0:t}" ]] && source "$ZSH/plugins/${0:h:t}/${0:t}"
