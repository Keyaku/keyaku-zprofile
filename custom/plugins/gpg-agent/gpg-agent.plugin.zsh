(( ${+commands[gpg-agent]} )) || return

GNUPGHOME="${GNUPGHOME:-XDG_DATA_HOME/gnupg}"

# Load available plugin from ohmyzsh
[[ -f "$ZSH/plugins/${0:h:t}/${0:t}" ]] && source "$ZSH/plugins/${0:h:t}/${0:t}"

if [[ ! -f "$GNUPGHOME/gpg-agent.conf" ]] || ! \grep -q 'pinentry-program' "$GNUPGHOME/gpg-agent.conf"; then
	echo "pinentry-program /usr/bin/pinentry" >> "$GNUPGHOME/gpg-agent.conf"
fi
