(( ${(v)#commands[(I)gpg|gpgconf]} )) || return

[[ -z "$GNUPGHOME" || "$GNUPGHOME" != "${XDG_DATA_HOME:-$HOME/.local/share}"/gnupg ]] && \
	export GNUPGHOME="${XDG_DATA_HOME:-$HOME/.local/share}"/gnupg
[[ -d "$GNUPGHOME" ]] || mkdir -p "$GNUPGHOME"
