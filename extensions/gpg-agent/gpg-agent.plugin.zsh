(( ${+commands[gpg-agent]} )) || return

# Set pinentry if not set in gpg-agent.conf
if ! \grep -qF 'pinentry-program /usr/bin/pinentry' "$GNUPGHOME/gpg-agent.conf"; then
	echo "pinentry-program /usr/bin/pinentry" >> "$GNUPGHOME/gpg-agent.conf"
fi

# Start gpg-agent with systemd
if has_systemd && ! systemctl --user -q is-active gpg-agent.socket; then
	systemctl --user -q start gpg-agent
fi
