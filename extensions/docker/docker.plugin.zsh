(( $+commands[docker] && ! $+commands[podman] )) || return

# Standardized $0 handling
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#zero-handling
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

# If the completion file doesn't exist yet, we need to autoload it and
# bind it to `docker`. Otherwise, compinit will have already done that.
if [[ ! -f "$ZSH_CACHE_DIR/completions/_docker" ]]; then
	typeset -g -A _comps
	autoload -Uz _docker
	_comps[docker]=_docker
fi

{
	# `docker completion` is only available from 23.0.0 on
	# docker version returns `Docker version 24.0.2, build cb74dfcd85`
	# with `s:,:` remove the comma after the version, and select third word of it
	autoload -Uz is-at-least
	if is-at-least 23.0.0 ${${(s:,:z)"$(command docker --version)"}[3]}; then
		command docker completion zsh | tee "$ZSH_CACHE_DIR/completions/_docker" > /dev/null
	fi
} &|

# Officially supported Docker environment variables
typeset -A DOCKER_ENV_VARS=(
	[DOCKER_API_VERSION]="Override the negotiated API version to use for debugging (e.g. 1.19)"
	[DOCKER_CERT_PATH]="Location of your authentication keys. This variable is used both by the docker CLI and the dockerd daemon"
	[DOCKER_CONFIG]="The location of your client configuration files."
	[DOCKER_CONTENT_TRUST_SERVER]="The URL of the Notary server to use. Defaults to the same URL as the registry."
	[DOCKER_CONTENT_TRUST]="When set Docker uses notary to sign and verify images. Equates to --disable-content-trust=false for build, create, pull, push, run."
	[DOCKER_CONTEXT]="Name of the docker context to use (overrides DOCKER_HOST env var and default context set with docker context use)"
	[DOCKER_CUSTOM_HEADERS]="(Experimental) Configure custom HTTP headers to be sent by the client. Headers must be provided as a comma-separated list of name=value pairs. This is the equivalent to the HttpHeaders field in the configuration file."
	[DOCKER_DEFAULT_PLATFORM]="Default platform for commands that take the --platform flag."
	[DOCKER_HIDE_LEGACY_COMMANDS]="When set, Docker hides "legacy" top-level commands (such as docker rm, and docker pull) in docker help output, and only Management commands per object-type (e.g., docker container) are printed. This may become the default in a future release."
	[DOCKER_HOST]="	Daemon socket to connect to."
	[DOCKER_TLS]="Enable TLS for connections made by the docker CLI (equivalent of the --tls command-line option). Set to a non-empty value to enable TLS. Note that TLS is enabled automatically if any of the other TLS options are set."
	[DOCKER_TLS_VERIFY]="When set Docker uses TLS and verifies the remote. This variable is used both by the docker CLI and the dockerd daemon"
	[BUILDKIT_PROGRESS]="Set type of progress output (auto, plain, tty, rawjson) when building with BuildKit backend. Use plain to show container output (default auto)."
)

# Custom Docker environment variables
typeset -A DOCKER_USER_VARS=(
	[DOCKER_ENV_VARS]="Dictionary with all officially supported Docker environment variables."
	[DOCKER_USER_VARS]="Dictionary with all user-defined Docker environment variables."
	[DOCKER_BIN]="Path to Docker binaries. Defaults to system installation"
	[DOCKER_HOME]="Path to general non-configuration Docker files. Defaults to /usr/local/docker for root, and \$HOME/.local/docker for non-root."
	[DOCKER_USER]="Current non-root user for Docker. Useful for containers where root is not necessary."
)

### Non-root operations
if (( 1000 <= $UID )); then
	### Current non-root docker user
	export DOCKER_USER="$(id -u):$(id -g)"
fi

# Set config directory, regardless of context
[[ -d "${XDG_CONFIG_HOME}/docker" ]] || mkdir -p "${XDG_CONFIG_HOME}/docker"
export DOCKER_CONFIG="${XDG_CONFIG_HOME}/docker"

# Checks current credention helper, fetching one if necessary
function docker-get-credhelper {
	local -r credhelper_repo="docker/docker-credential-helpers"
	local -r credhelper_api="api.github.com/repos/${credhelper_repo}/releases"
	local -r DOCKER_CACHE="${XDG_CACHE_HOME}/docker"
	[[ -d "${DOCKER_CACHE}" ]] || mkdir -p "${DOCKER_CACHE}"
	curl -o "${DOCKER_CACHE}/credhelper-releases.json" -s https://${credhelper_api}/latest || return $?

	# 1. Define credential store
	local -ra credhelper_valid=("pass" "secretservice" "osxkeychain" "wincred")
	local credstore="pass"
	if (( $# )); then
		[[ "${credhelper_valid[(r)$1]}" ]] && credstore="$1"
	fi

	# 2. If credstore is `pass`, check if it's installed
	if [[ "$credstore" == "pass" ]] && (( ! ${+commands[pass]} )); then
		local pkgmgr="$(pkgmgr-get)"
		print_fn -e "pass not installed.${pkgmgr:+ Install it via $pkgmgr.}"
		return 1
	fi

	# 3. Check if docker-credential-helper is installed and if it's the latest version
	local latest_version="$(jq -r '.tag_name' "${DOCKER_CACHE}/credhelper-releases.json")"
	local local_version
	local -i needs_update=1

	if (( ${+commands[docker-credential-${credstore}]} )); then
		local_version="$(docker-credential-${credstore} -v | awk '{print $NF}')"
		[[ "$local_version" == "$latest_version" ]] && needs_update=0
	fi

	if (( ! $needs_update )); then
		echo "docker-credential-${credstore} is up-to-date."
		return 0
	fi

	# If not, fetch latest release
	local arch
	case "$(uname -m)" in
		arm* ) arch=arm64 ;;
		* ) arch=amd64 ;;
	esac
	local kernel="$(uname -s | tr '[:upper:]' '[:lower:]')"
	local asset_name="docker-credential-${credstore}-${latest_version}.${kernel}-${arch}"
	jq -r '.assets[] | select(.name | contains ("'${asset_name}'"))' "${DOCKER_CACHE}/credhelper-releases.json" > "${DOCKER_CACHE}/credhelper-asset.json"
	if [[ ! -s "${DOCKER_CACHE}/credhelper-asset.json" ]]; then
		print_fn -e "Asset '$asset_name' not found"
		return 1
	fi

	echo "Downloading latest docker-credential-${credstore}..."
	local browser_download_url="$(jq -r '.browser_download_url' "${DOCKER_CACHE}/credhelper-asset.json")"
	curl -L -o "$HOME/.local/bin/docker-credential-${credstore}" "${browser_download_url}"
	chmod ug+x "$HOME/.local/bin/docker-credential-${credstore}"

	# Cleanup
	rm -f "${DOCKER_CACHE}"/credhelper-*.json

	echo "Done. Run 'docker-credential-${credstore}' to check if it's working."
}

# Sets environment for Docker
function docker-set-env {
	if ! command-has systemctl-service-path; then
		zsource system.zsh
	fi

	### If rootless binaries exist, prefer those over rootful
	if [[ -f "$(systemctl-service-path --user docker)" ]]; then
		### Set important environment variables
		export DOCKER_BIN="${XDG_DATA_HOME}/docker/bin"
		DOCKER_HOME="$HOME/.local/docker"

		# Prepend binary directory to PATH
		addpath -p "$DOCKER_BIN"

		### Check if systemd service is running but is not in rootless context
		if systemctl --user is-active -q docker && [[ "$(docker context show)" != "rootless" ]]; then
			unset DOCKER_HOST DOCKER_CONTEXT # Can only set rootless context with such variable(s) as unset
			docker context use rootless >/dev/null || {
				# In case of failure, set DOCKER_HOST
				docker-set-host -q
			}
		fi

	### Otherwise, assume default system-wide installation
	else
		### Set important environment variables
		DOCKER_BIN="$(pkgmgr-binpath docker 2>/dev/null)"
		DOCKER_HOME="/usr/local/docker"
	fi
}

# If docker is running, set DOCKER_HOST variable. Run this only if necessary.
function docker-set-host {
	local -r usage=(
		"Usage: $(get_funcname) [OPTION...]"
		"\t[-h|--help]"
		"\t[-v] / [-q] : Increase / Decrease verbosity"
	)

	## Setup func opts
	local f_help f_verbosity
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		v+=f_verbosity q+=f_verbosity \
		|| return 1

	## Help/usage message
	if [[ "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	# Verbosity
	local -i verbosity=1 # defaults to some verbosity
	f_verbosity="${(j::)f_verbosity//-}"
	(( verbosity += (${#f_verbosity//q} - ${#${f_verbosity//v}}) ))


	# Set docker host variable
	docker ps >/dev/null && {
		local docker_host="$(docker context inspect -f '{{.Endpoints.docker.Host}}' $(docker context show))"
		# Only set DOCKER_HOST if current context is not default

		if [[ "$(docker context show)" != "default" ]]; then
			print_fn -e "Current Docker context is not default. This is most likely unintended behavior."
			return 1
		elif [[ "$DOCKER_HOST" != "$docker_host" ]]; then
			export DOCKER_HOST="$docker_host"
			(( 0 < $verbosity )) && printenv DOCKER_HOST
		fi
	}
}

# Helper to install Docker rootless via URL
function docker-rootless-install {
	if (( ! ${+commands[curl]} )); then
		print_fn -e "curl not installed"
		return 1
	fi

	if systemctl is-active -q docker; then
		echo "Disabling system Docker..."
		sudo systemctl disable --now docker.service docker.socket
		sudo rm "$(systemctl cat docker.socket | sed -En 's|^ListenStream=||p')"
	fi

	DOCKER_BIN="${XDG_DATA_HOME}/docker/bin"
	if [[ ! -d "$DOCKER_BIN" ]]; then
		echo "Creating user directories..."
		mkdir -p "$DOCKER_BIN"
	fi
	echo "Fetching and executing Docker rootless install script..."
	curl -fsSL https://get.docker.com/rootless | DOCKER_BIN="${DOCKER_BIN}" sh || return $?
	docker-set-env

	echo "Exposing privileged ports..."
	sudo setcap cap_net_bind_service=ep $(which rootlesskit)

	ask --yn -k "Do you want Docker rootless to start at boot?" && {
		systemctl --user enable docker
		sudo loginctl enable-linger $(whoami)
	}

	echo "Final Docker restart..."
	systemctl --user restart docker
}

# Helper to uninstall Docker rootless
function docker-rootless-uninstall {
	local -r usage=(
		"Usage: $(get_funcname) [OPTION...]"
		"\t[-h|--help] : Prints this message"
		"\t[-f|--full] : Fully removes all Docker rootless binaries"
		"\t[-d|--daemon] : Removes only the daemon. Useful for updating"
	)

	## Setup func opts
	local f_help f_full f_quiet
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{f,-full}=f_full \
		{d,-daemon}=f_daemon \
		|| return 1

	## Help/usage message
	if [[ "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	if [[ "$f_full" && "$f_daemon" ]]; then
		print_fn -e "-d and -f flags are mutually exclusive"
		return 2
	fi

	# Setting DOCKER_BIN just in case
	[[ "$DOCKER_BIN" != "${XDG_DATA_HOME}/docker/bin" ]] && export DOCKER_BIN="${XDG_DATA_HOME}/docker/bin"
	# Checking environment
	if [[ -z "$(ls "${DOCKER_BIN}" 2>/dev/null)" ]]; then
		echo "Docker rootless not installed"
		return 0
	elif [[ -z "${f_full}" ]] && ! haspath "${DOCKER_BIN}"; then
		echo "Docker rootless not in \$PATH, but binaries found (a.k.a. soft uninstalled). Use -f to force remove"
		return 0
	elif [[ -z "${f_full}" ]] && (( ! ${+commands[dockerd-rootless-setuptool.sh]} )); then
		print_fn -e "Uninstall script not found, but binaries found. Use -f to force remove"
		return 1
	fi

	if systemctl --user is-active -q docker; then
		echo "Stopping docker service..."
		systemctl --user stop docker
	fi
	if [[ "$f_daemon" && -f "${DOCKER_BIN}"/dockerd ]]; then
		echo "Deleting docker daemon..."
		rm -f "${DOCKER_BIN}"/dockerd
	else
		(( ${+commands[dockerd-rootless-setuptool.sh]} )) && dockerd-rootless-setuptool.sh uninstall
		rmpath "${DOCKER_BIN}"
		[[ "$f_full" ]] && rm -rf "${DOCKER_BIN}"
	fi
}

# Check if docker is running and if the given container exists
function docker-has {
	docker info > /dev/null 2>&1 || return $?

	while (( $# )); do
		docker ps -a --format '{{.Names}}' | \grep -qw "$1" || return $?
		shift
	done
}

function docker-getpath {
	while (( $# )); do
		find "$DOCKER_HOME/stacks" -not -empty -type d -name "$1" | \grep . || return $?
		shift
	done
}

# Check if there's a docker container environment under DOCKER_HOME for the given argument
function docker-ls {
	local args=() cmd_args=()

	### Parse args
	while (( $# )); do
		case $1 in
		-* )
			cmd_args+=($1)
		;;
		* ) args+=($1)
		;;
		esac
		shift
	done
	set -- ${args[@]}

	if (( ! $# )); then
		ls ${cmd_args[@]} "$DOCKER_HOME/stacks"
	else
		### Check if under DOCKER_HOME
		docker-getpath $@ | tee >(xargs ls ${cmd_args[@]})
	fi
}

# Updates Docker binaries. Only works for rootless; for system-wise, best to use package managers
function docker-update {
	if [[ "$(docker context show 2>/dev/null)" != rootless ]]; then
		print_fn -e "Current context isn't rootless, so it most likely doesn't need manual updating."
		return 1
	fi

	docker-rootless-uninstall -d
	docker-rootless-install
}

function docker-upgrade {
	if (( ! $# )); then
		print_fn -e "Docker stack name(s) required as argument(s)"
		return 1
	fi

	while (( $# )); do
		local stack="$(docker-getpath "$1")"
		## If stack directory was found
		if [[ -d "$stack" ]]; then
			(cd "$stack"
				docker compose down
				docker compose pull
				docker compose up -d
			)
		else
			print_fn -e "Stack not found under $DOCKER_HOME/stacks: '$1'"
		fi
		shift
	done
}

### Docker socket creation
function docker-socket-tls {
	local PATH_pass=/tmp/ca_passphrase
	local pass
	local SIGNALS=(HUP INT QUIT KILL TERM)

	cleanup() {
		local retval=${1:-0}

		trap - ${SIGNALS[@]}
		rm -f $PATH_pass

		return $retval
	}
	trap 'cleanup 1' ${SIGNALS[@]}

	# Setting up directories
	local DOCKER_CERT_PATH="$DOCKER_HOME/certs"
	if [[ ! -d "$DOCKER_CERT_PATH" ]]; then
		mkdir -p "$DOCKER_CERT_PATH"

		# Ask for passphrase
		touch $PATH_pass
		chmod 600 $PATH_pass
		printf "Enter PEM pass phrase: "
		read -s pass && echo $pass >> $PATH_pass
		unset pass
		echo $pass

		echo "Creating server certificates..."
		# Create new CA
		openssl genrsa -aes256 -out $DOCKER_CERT_PATH/ca-key.pem -passout file:$PATH_pass 4096 || return 1
		openssl req -new -x509 -days 365 -key $DOCKER_CERT_PATH/ca-key.pem -sha256 -out $DOCKER_CERT_PATH/ca.pem -passin file:$PATH_pass \
			-subj "/C=PT/ST=Lisbon/L=Lisbon/O=Sarmento/OU=IT Department" || return 1

		# Create server CSR
		openssl genrsa -out $DOCKER_CERT_PATH/server-key.pem 4096 || return 1
		openssl req -subj "/CN=$HOST" -sha256 -new -key $DOCKER_CERT_PATH/server-key.pem -out server.csr || return 1

		# Sign public key with CA
		echo subjectAltName = DNS:$HOST,IP:127.0.0.1 >> extfile.cnf
		echo extendedKeyUsage = serverAuth >> extfile.cnf
		openssl x509 -req -days 365 -sha256 -in server.csr -CA $DOCKER_CERT_PATH/ca.pem -CAkey $DOCKER_CERT_PATH/ca-key.pem \
			-CAcreateserial -out $DOCKER_CERT_PATH/server-cert.pem -passin file:$PATH_pass -extfile extfile.cnf || return 1

		echo "Creating client certificates..."
		# Create client key and CSR
		openssl genrsa -out $DOCKER_CERT_PATH/key.pem 4096 || return 1
		openssl req -subj '/CN=client' -new -key $DOCKER_CERT_PATH/key.pem -out client.csr || return 1
		echo extendedKeyUsage = clientAuth > extfile-client.cnf

		# Generate certificate
		openssl x509 -req -days 365 -sha256 -in client.csr -CA $DOCKER_CERT_PATH/ca.pem -CAkey $DOCKER_CERT_PATH/ca-key.pem \
			-CAcreateserial -out $DOCKER_CERT_PATH/cert.pem -passin file:$PATH_pass -extfile extfile-client.cnf || return 1

		echo "Setting up service..."
		# Clean up
		rm client.csr server.csr extfile.cnf extfile-client.cnf
		chmod 0400 $DOCKER_CERT_PATH/{ca-key,key,server-key}.pem
		chmod 0444 $DOCKER_CERT_PATH/{ca,server-cert,cert}.pem
	else
		echo "'$DOCKER_CERT_PATH' already exists. Skipping"
	fi

	# Setting up service override configuration
	local PATH_svc="$(systemctl --user cat docker 2>/dev/null | head -n1 | awk '{print $NF}')"
	if [[ ! -f "${PATH_svc}.d/override.conf" ]]; then
		mkdir -p "${PATH_svc}.d"
		cp "$ZDOTDIR/conf/docker/$(get_funcname).conf" ${PATH_svc}.d/override.conf
	else
		echo "'${PATH_svc}.d/override.conf' already exists. Skipping"
	fi

	# Setting up context
	if ! docker context ls | \grep -q rootless-tls; then
		echo "Creating context..."
		docker context create rootless-tls \
			--docker "host=tcp://0.0.0.0:2376,ca=${DOCKER_CERT_PATH}/ca.pem,cert=${DOCKER_CERT_PATH}/server-cert.pem,key=${DOCKER_CERT_PATH}/server-key.pem" \
			--description "Rootless TLS context" || return 1
	else
		echo "Context 'rootless-tls' already exists. Skipping"
	fi
	docker context use rootless-tls

	# Reload systemd settings
	systemctl --user daemon-reload || return 1
	systemctl --user restart docker || return 1

	cleanup
}

# SSH socket
function docker-socket-ssh {
	if ! docker context ls | \grep -q rootless-ssh; then
		docker context create rootless-ssh \
			--docker "host=ssh://$USER@$HOST" \
			--description="Rootless SSH context"
	fi

	if [[ ! -f "$SSH_HOME/config.d/docker.conf" ]]; then
		# Adding configuration
		[[ -d "$SSH_HOME/config.d" ]] || mkdir -p "$SSH_HOME/config.d"

		cp "$ZDOTDIR/conf/docker/$(get_funcname).conf" $SSH_HOME/config.d/docker.conf

		# Checking if config file exists and contains an Include directive
		[[ ! -f "$SSH_HOME/config" ]] && touch "$SSH_HOME/config"
		if ! \grep -q 'Include /home/%u/.local/config/ssh/config.d/*.conf' "$SSH_HOME/config"; then
			sed -i '1s;^;Include /home/%u/.local/config/ssh/config.d/*.conf\n\n;' "$SSH_HOME/config"
		fi
	fi

	docker context use rootless-ssh
}


#######################################
### Container-specific commands
#######################################

# Function which defines container aliases
function docker-alias {
	local -r usage=(
		"Usage: ${funcstack[1]} [-n|--name=]<container_name> [-a|--alias=<alias_name>] [-c|--cmd=]<command>"
		"\t[-h|--help]"
	)

	## Setup func opts
	local f_help
	local container_name container_alias container_cmd
	local container_user
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{n,-name}:=container_name \
		{a,-alias}:=container_alias \
		{c,-cmd}:=container_cmd \
		{u,-user}:=container_user \
		|| return 1

	## Help/usage message
	if (( ! $# )) || [[ "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	# Presume 1st argument is container_name
	if [[ -z "$container_name" && "$1" ]]; then
		container_name="$1"
		shift
	else # Otherwise, check if it's a flag
		[[ "${(t)container_alias}" == *array* ]] && container_name="${container_name[-1]}"
	fi

	# Presume rest of arguments are for container_cmd
	(( $# )) && container_cmd="$*"

	## Check required arguments
	# If everything's empty, let user know at least container name is required
	if [[ -z "${container_name}${container_alias}${container_cmd}" ]]; then
		print_fn -e "requires at least a container name"
		return 1
	fi
	[[ "${(t)container_alias}" == *array* ]] && container_alias="${(q+)container_alias[-1]}" || container_alias="${container_alias:-$container_name}"
	[[ "${(t)container_cmd}" == *array* ]] && container_cmd="${(q+)container_cmd[-1]}" || container_cmd="${container_cmd:-$container_name}"

	# Define alias
	alias $container_alias="docker exec ${container_user:+--user $container_user[-1]} $container_name $container_cmd"
}

# Defining simple container aliases
DOCKER_CONTAINERS_CMD=(
	caddy cloudflared mollysocket ntfy ollama
)
for container_name in ${DOCKER_CONTAINERS_CMD}; do
	docker-has "$container_name" &&	docker-alias "$container_name"
done
unset DOCKER_CONTAINERS_CMD container_name

# Defining more complex aliases
docker-alias -a occ -n nextcloud -u www-data "php occ"
