###################
### Control
###################

# Caddy
if command-has caddy; then
	alias caddy-reload='caddy reload --config /etc/caddy/Caddyfile'
fi

# Cloudflare
if command-has cloudflared; then
	# If this computer is a cloudflared server, load extra functions
	if [[ -d "/usr/local/etc/cloudflare/data" ]]; then
		export CF_CONF_HOME="/usr/local/etc/cloudflare/data"
		export TUNNEL_ORIGIN_CERT=$CF_CONF_HOME/cert.pem

		function cloudflared_add_service {
			echo "CAREFUL! Use this tool only if you know what you're doing!"
			check_envvars "SERVER_NAME" || return 1

			local hostname=""
			local service=""

			# Setting hostname variable
			if [[ -z "$1" ]]; then
				ask -p "hostname (CNAME.$SERVER_NAME, e.g. pi.$SERVER_NAME):"
				hostname="$REPLY"
			else
				hostname="$1"
			fi

			# Setting service variable
			if [[ -z "$2" ]]; then
				ask -p "service (e.g. For SSH: ssh://localhost:22):"
				service="$REPLY"
			else
				service="$2"
			fi

			# Editing config file
			local config="$CF_CONF_HOME/config.yml"
			local linenum="$(( $(awk '/http_status:404/{ print NR; exit }' $config) - 1))"
			sed -i "$linenum i \  - hostname: $hostname\n    service: $service" $config || return 1

			# Validate and reload configuration
			cloudflared tunnel validate || return 1

			# Adding DNS record
			cloudflared tunnel route dns $HOST $hostname || return 1

			docker restart cloudflared
		}
	fi
fi
