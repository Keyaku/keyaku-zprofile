(( ${+commands[caddy]} || ${+aliases[caddy]} )) || return

local _caddyfile
if [[ "${aliases[caddy]}" == *docker* || "${aliases[caddy]}" == *podman* ]]; then
	_caddyfile="/etc/caddy/Caddyfile"
else
	_caddyfile="${CADDYFILE:-/etc/caddy/Caddyfile}"
fi

alias caddy-reload="caddy reload --config ${_caddyfile}"
alias caddy-fmt="caddy fmt --overwrite ${_caddyfile}"
