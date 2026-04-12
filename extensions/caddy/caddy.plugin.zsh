(( ${+commands[caddy]} || ${+aliases[caddy]} )) || return

# FIXME: This works better with the default caddy config (which also works with docker)
# but not with a user-defined path.
alias caddy-reload="caddy reload --config /etc/caddy/Caddyfile"
alias caddy-fmt="caddy fmt /etc/caddy/Caddyfile"
