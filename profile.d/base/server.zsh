###################
### Control
###################

# Caddy
if command_has caddy; then
	alias caddy-reload='caddy reload --config /etc/caddy/Caddyfile'
fi

# Cloudflare
if command_has cloudflared; then
	# If this computer is a cloudflared server, load extra functions
	if [[ -d "/usr/local/etc/cloudflare/data" ]]; then
		export CF_CONF_HOME="/usr/local/etc/cloudflare/data"
		export TUNNEL_ORIGIN_CERT=$CF_CONF_HOME/cert.pem

		function cloudflared_add_service {
			echo "CAREFUL! Use this tool only if you know what you're doing!"
			if [[ -z "$SERVER_NAME" ]]; then
				print_error "SERVER_NAME environment variable not set"
			fi

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


# MEGA
if command_has megacli; then
	if [[ ${SHELL##*/} == bash ]]; then
		. /usr/local/etc/bash_completion.d/megacmd_completion.sh
	fi
	function mega-update {
		if [[ -d "$GIT_HOME/MEGAcmd" ]]; then
			cd "$GIT_HOME/MEGAcmd"
			git pull && git submodule update --recursive --remote
			make && make install
		else
			echo "Unable to update megacli. How did you install it?"
			return 1
		fi
	}
fi

# UISP
if [[ -d /home/unms ]]; then
	alias unms-start='sudo /home/unms/app/unms-cli start'
	alias unms-stop='sudo /home/unms/app/unms-cli stop'
fi


###################
### Web development
###################
if command_has sass; then
	alias sass-watch='sass --watch resources/sass/main.scss:public/css/main.min.css --style compressed > /var/log/sass/watch.log 2>&1 &'
fi
