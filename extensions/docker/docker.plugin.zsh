(( $+commands[docker] )) || return

# Standardized $0 handling
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#zero-handling
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

### Docker-specific functions; either incompatible with Podman, or cause more trouble than they should
if (( ! $+commands[podman] )); then
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
			print_fn -e "pass not installed."
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
			zsource -L
		fi

		### If rootless binaries exist, prefer those over rootful
		if has_user_systemd && systemctl-service-path --user docker &>/dev/null; then
			### Set important environment variables
			export DOCKER_BIN="${XDG_DATA_HOME}/docker/bin"
			DOCKER_HOME="${DOCKER_CONFIG:-$XDG_CONFIG_HOME/docker}"

			# Prepend binary directory to PATH
			addpath 1 "$DOCKER_BIN"

			### Check if systemd service is running but is not in rootless context
			if systemctl --user is-enabled -q docker && [[ "$(docker context show)" != "rootless" ]]; then
				unset DOCKER_HOST DOCKER_CONTEXT # Can only set rootless context with such variable(s) as unset
				docker context use rootless >/dev/null || {
					# In case of failure, set DOCKER_HOST
					docker-set-host -q
				}
			fi

		### Otherwise, assume default system-wide installation
		else
			### Set important environment variables
			DOCKER_BIN="$(sysbinpath docker 2>/dev/null)"
			DOCKER_HOME="/usr/local/docker"
			unset DOCKER_HOST
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
		curl -fsSL https://get.docker.com/rootless | DOCKER_BIN="${DOCKER_BIN}" sh $@ || return $?
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
			print_fn -e "Flags -d and -f are mutually exclusive"
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

		# Change context before disabling
		docker context use default
		docker context rm rootless >/dev/null

		if systemctl --user is-enabled -q docker; then
			echo "Stopping docker service..."
			systemctl --user disable --now docker
		fi
		if [[ "$f_daemon" && -f "${DOCKER_BIN}"/dockerd ]]; then
			echo "Deleting docker daemon..."
			rm -f "${DOCKER_BIN}"/dockerd
		else
			(( ${+commands[dockerd-rootless-setuptool.sh]} )) && dockerd-rootless-setuptool.sh uninstall
			rmpath "${DOCKER_BIN}"
			[[ "$f_full" ]] && rm -rf "${DOCKER_BIN}"
		fi

		docker-set-env

		ask --yn -k "Disable login linger for $USER?" && sudo loginctl disable-linger $USER
	}

	# Updates rootless Docker binaries.
	function docker-rootless-update {
		if [[ "$(docker context show 2>/dev/null)" != rootless ]]; then
			print_fn -e "Current context isn't rootless, so it most likely doesn't need manual updating."
			return 1
		fi

		docker-rootless-uninstall -d
		docker-rootless-install
	}

	# Docker socket creation
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
			cp "$ZDOTDIR/conf/etc/docker/$(get_funcname).conf" ${PATH_svc}.d/override.conf
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

			cp "$ZDOTDIR/conf/home/docker/$(get_funcname).conf" $SSH_HOME/config.d/docker.conf

			# Checking if config file exists and contains an Include directive
			[[ ! -f "$SSH_HOME/config" ]] && touch "$SSH_HOME/config"
			if ! \grep -q 'Include /home/%u/.local/config/ssh/config.d/*.conf' "$SSH_HOME/config"; then
				sed -i '1s;^;Include /home/%u/.local/config/ssh/config.d/*.conf\n\n;' "$SSH_HOME/config"
			fi
		fi

		docker context use rootless-ssh
	}

	# Install the btrfs nodatacow watcher + weekly audit for DB docker volumes,
	# if the Docker daemon root sits on btrfs. Idempotent. Needs sudo.
	function docker-nodatacow-install {
		local -r usage=(
			"Usage: $(get_funcname) [-h|--help] [-n|--dry-run]"
		)
		local f_help f_dryrun
		zparseopts -D -F -K -- \
			{h,-help}=f_help \
			{n,-dry-run}=f_dryrun \
			|| return 1

		if [[ -n "$f_help" ]]; then
			>&2 print -l $usage
			return 0
		fi

		local root="$(docker info -f '{{.DockerRootDir}}' 2>/dev/null)"
		if [[ -z "$root" || ! -d "$root" ]]; then
			print_fn -e "could not determine Docker root dir (is the daemon running?)"
			return 1
		fi
		local fstype="$(command stat -f -c %T "$root" 2>/dev/null)"
		if [[ "$fstype" != btrfs ]]; then
			print_fn -w "Docker root '$root' is on '$fstype', not btrfs - nothing to install"
			return 0
		fi
		# Rootful-only: this function installs system-wide systemd units and
		# targets /var/lib/docker/volumes. Bail if Docker is rootless.
		if [[ "$root" != /var/lib/docker* ]]; then
			print_fn -e "Docker root '$root' looks rootless; this installer only supports rootful Docker"
			return 1
		fi

		local SRC="$ZDOTDIR/conf/etc/docker/nodatacow"
		local run="${f_dryrun:+echo}"
		echo "Installing nodatacow watcher + audit (rootful Docker on btrfs)"
		# Symlink code so plugin-repo updates flow through live; copy
		# overrides.list as a template only if absent (preserves local edits).
		$run sudo install -d -m 0755 /usr/local/etc/nodatacow
		if [[ ! -e /usr/local/etc/nodatacow/overrides.list ]]; then
			$run sudo install -m 0644 "$SRC/overrides.list" /usr/local/etc/nodatacow/overrides.list
		fi
		$run sudo ln -sfn "$SRC/nodatacow-apply.zsh"     /usr/local/bin/nodatacow-apply.zsh
		$run sudo ln -sfn "$SRC/nodatacow.path"          /etc/systemd/system/nodatacow.path
		$run sudo ln -sfn "$SRC/nodatacow.service"       /etc/systemd/system/nodatacow.service
		$run sudo ln -sfn "$SRC/nodatacow-audit.service" /etc/systemd/system/nodatacow-audit.service
		$run sudo ln -sfn "$SRC/nodatacow-audit.timer"   /etc/systemd/system/nodatacow-audit.timer
		$run sudo systemctl daemon-reload
		$run sudo systemctl enable --now nodatacow.path nodatacow-audit.timer

		print -l \
			"" \
			"Done. Verify with: sudo /usr/local/bin/nodatacow-apply.zsh --audit" \
			"" \
			"Audit ntfy notifications (optional but recommended):" \
			"  The weekly audit posts high-priority alerts to ${NTFY_URL:-http://127.0.0.1:2586}/nodatacow" \
			"  when a DB volume drifts back to CoW. Without a token it logs to journal only." \
			"  To enable:" \
			"    echo 'tk_YOUR_TOKEN' | sudo tee /usr/local/etc/nodatacow/ntfy-token >/dev/null" \
			"    sudo chmod 600 /usr/local/etc/nodatacow/ntfy-token"
	}

### In case of Podman being installed
else
	# Don't set anything. Podman isn't picky.
	function docker-set-env {
		unset DOCKER_HOST # Safety unset

		# Warn user about being in docker group despite using Podman
		if id -nG "$USER" | grep -qw "docker"; then
			print -u2 "$(get_funcname): User $USER is currently in group 'docker' despite using Podman."
			print -u2 "Detach from it using:\n> sudo gpasswd -d \"$USER\" \"docker\""
		fi
	}
fi

# List all existing Docker items following a given format. Uses format '.Names' if no argument given.
function docker-list {
	local fmt="${@:-.Names}"
	docker ps -a --format "{{$fmt}}"
}

# Check if the given Docker projects exist
function docker-has {
	# Exit on error, e.g. Docker is not running or returns nothing
	setopt local_options err_return

	local -r usage=(
		"Usage: $(get_funcname) [OPTION...] CONTAINER..."
		"\t[-h|--help]"
		"\t[-a|--any] : Return true if any container exists (default)"
		"\t[-A|--all] : Return true only if all containers exist"
	)

	local f_help f_any f_all
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{a,-any}=f_any \
		{A,-all}=f_all \
		|| return 1

	if [[ "$f_help" ]]; then
		>&2 print -l $usage
		return 0
	fi

	(( $# )) || return 1

	local -a names
	names=(${(f)"$(docker-list)"})

	local container
	for container in "$@"; do
		if (( ${names[(Ie)$container]} )); then
			[[ -z "$f_all" ]] && return 0
		else
			[[ -n "$f_all" ]] && return 1
		fi
	done

	[[ -n "$f_all" ]] && return 0
	return 1
}

function docker-get-compose {
	docker inspect "$@" --format '{{index .Config.Labels "com.docker.compose.project"}}: {{index .Config.Labels "com.docker.compose.project.config_files"}}' 2>/dev/null
}

function docker-upgrade {
	local -r usage=(
		"Usage: $(get_funcname) [OPTION...] CONTAINER..."
		"\t[-h|--help]"
		"\t[-d|--dry-run] : Print commands without executing"
	)

	local f_help f_dryrun
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{d,-dry-run}=f_dryrun \
		|| return 1

	if [[ "$f_help" ]]; then
		>&2 print -l $usage
		return 0
	fi

	if (( ! $# )); then
		print_fn -e "Container name(s) required as argument(s)"
		return 1
	fi

	if [[ "$f_dryrun" ]]; then
		f_dryrun="echo"
		echo "Dry-run mode enabled"
	fi

	local container compose_file running
	for container in "$@"; do
		{ read -r running; read -r compose_file; } < <(docker inspect "$container" \
			--format $'{{.State.Running}}\n{{index .Config.Labels "com.docker.compose.project.config_files"}}' 2>/dev/null)

		if [[ -z "$compose_file" ]]; then
			print_fn -e "'$container': not found or not part of a compose stack"
			continue
		fi

		if [[ "$running" != "true" ]]; then
			print_fn -w "'$container': not running, skipping"
			continue
		fi

		if [[ "$compose_file" == /data/compose/* ]]; then
			print_fn -w "'$container': managed by Portainer, skipping"
			continue
		fi

		$f_dryrun docker compose -f "$compose_file" down &&\
			$f_dryrun docker compose -f "$compose_file" pull &&\
			$f_dryrun docker compose -f "$compose_file" up -d
	done
}

# Function which defines container command wrappers.
#
# Defines a *function* (not an alias) that runs a command inside a container
# via `docker exec`. Functions are used deliberately: an alias would expand to
# `docker ...` for completion, so `<alias> <TAB>` wrongly fires docker's own
# completion. A function gets no auto-completion, so nothing leaks; the inner
# command's real completion is then linked via `docker-container-completion`
# (cached from inside the container) when it supports `completion zsh`.
function docker-container-cmd {
	local -r usage=(
		"Usage: $(get_funcname) [-n|--name=]<container_name> [-a|--alias=<alias_name>] [-c|--cmd=]<command>"
		"\t[-h|--help] : Prints this message"
		"\t[-n|--name] : Name of the target container"
		"\t[-a|--alias] : Name of the resulting command/wrapper"
		"\t[-c|--cmd] : Command to send to the container"
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

	# Define the wrapper function. The resolved exec command is baked in;
	# "$@" is escaped so it stays literal in the function body.
	local exec_cmd="docker exec -it ${container_user:+--user ${container_user[-1]}} $container_name $container_cmd"
	functions[$container_alias]="$exec_cmd \"\$@\""

	# Link the inner command's own zsh completion to the wrapper.
	docker-container-completion "$container_alias" "$container_name" ${=container_cmd}
}

# Link a container command's own zsh completion to its wrapper function.
#
# Usage: docker-container-completion <alias> <container> [<cmd>...]
#
# Caches the command's own zsh completion script (generated *inside* the
# container) to $ZSH_CACHE_DIR/completions/container/<alias>.zsh, sources it, and
# binds the generated completion function to <alias>. The function name is
# derived from the cached script, so it works regardless of name mismatch (e.g.
# `occ` from `php occ`). Once cached, every later shell binds with zero docker
# calls.
#
# When not yet cached, generation runs in the background (mirroring the
# `_docker` bootstrap above): the completion appears in the *next* shell, not
# the current one. Both `completion` and `completions` subcommands are probed
# (cobra uses the former, clap-based CLIs the latter); output is kept only if
# it's a real completion script (carries a `compdef`/`#compdef` marker), else
# discarded. Commands that ship neither silently get nothing. Refresh after a
# tool upgrade by deleting the cache dir.
function docker-container-completion {
	local alias_name="$1" container="$2"; shift 2
	local -a cmd=("$@")
	(( ${#cmd} )) || cmd=("$alias_name")

	local comp_dir="${ZSH_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh}/completions/container"
	local comp_file="$comp_dir/${alias_name}.zsh"

	# Already cached: derive the fn (which also validates the script), source,
	# bind. No docker call. The fn is derived *before* sourcing so a non-script
	# (e.g. a help blurb on stdout) is never executed.
	if [[ -s "$comp_file" ]]; then
		local realfn
		realfn="$(_docker-container-comp-fn "$comp_file")"
		if [[ -n "$realfn" ]]; then
			source "$comp_file"
			(( $+functions[$realfn] )) && compdef "$realfn" "$alias_name"
			return
		fi
		# Stale/invalid cache (e.g. tool dropped completion support): drop it
		# and fall through to regenerate.
		rm -f "$comp_file"
	fi

	# Not cached: generate in the background so it's ready next shell. Probe
	# both subcommand spellings; keep the first that yields a valid script.
	[[ -d "$comp_dir" ]] || mkdir -p "$comp_dir"
	{
		local sub
		for sub (completion completions); do
			docker exec "$container" "${cmd[@]}" $sub zsh >| "$comp_file" 2>/dev/null
			[[ -n "$(_docker-container-comp-fn "$comp_file")" ]] && break
			rm -f "$comp_file"
		done
	} &|
}

# Derive the completion function name (`_foo`) from a generated zsh completion
# script. Prefers the `compdef _foo foo` directive, falls back to the `_foo()`
# definition line. POSIX ERE only (Termux zsh lacks PCRE).
function _docker-container-comp-fn {
	local f="$1" name
	name="$(grep -m1 -oE '^compdef +_[[:alnum:]_-]+' "$f" 2>/dev/null | grep -oE '_[[:alnum:]_-]+$')"
	[[ -z "$name" ]] && name="$(grep -m1 -oE '^(function +)?_[[:alnum:]_-]+ *\(\)' "$f" 2>/dev/null | grep -oE '_[[:alnum:]_-]+')"
	print -r -- "$name"
}

# Migrate data from a container's volume/bind mount to another volume or directory
function docker-migrate-volume {
	local -r usage=(
		"Usage: $(get_funcname) [OPTION...] [<container>] [<src>] [<dst>]"
		"\t[-h|--help]      : Prints this message"
		"\t[-n|--dry-run]   : Print steps without executing"
		"\t[-k|--keep]      : Keep source after migration (manual cleanup)"
		"\t[--name <name>]  : Container name (non-positional)"
		"\t[--src <path>]   : Source bind mount path or named volume"
		"\t[--dst <path>]   : Destination bind mount path or named volume"
	)

	local f_help f_dryrun f_keep
	local -a f_cname=() f_src=() f_dst=()
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{n,-dry-run}=f_dryrun \
		{k,-keep}=f_keep \
		-name:=f_cname \
		-src:=f_src \
		-dst:=f_dst \
		|| return 1

	if [[ "$f_help" ]]; then
		>&2 print -l $usage
		return 0
	fi

	local DRYRUN="${f_dryrun:+echo}"

	# Named flags take priority over positional args
	local container_name src dst
	(( ${#f_cname} )) && container_name="${f_cname[-1]}"
	(( ${#f_src}   )) && src="${f_src[-1]}"
	(( ${#f_dst}   )) && dst="${f_dst[-1]}"

	[[ -z "$container_name" && $# -ge 1 ]] && { container_name="$1"; shift; }
	[[ -z "$src"            && $# -ge 1 ]] && { src="$1"; shift; }
	[[ -z "$dst"            && $# -ge 1 ]] && { dst="$1"; shift; }

	# Validate required arguments
	[[ -z "$container_name" ]] && { print_fn -e "Container name required"; return 1; }
	[[ -z "$src"            ]] && { print_fn -e "Source volume/path required"; return 1; }
	[[ -z "$dst"            ]] && { print_fn -e "Destination volume/path required"; return 1; }

	# Validate container exists
	docker-has "$container_name" || { print_fn -e "Container '$container_name' not found"; return 1; }

	# Warn if container is running — live data may be inconsistent
	if [[ "$(docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null)" == "true" ]]; then
		print_fn -w "Container '$container_name' is running. Migrating live data may cause inconsistencies."
	fi

	# Classify type: anything with '/' is a bind mount path; otherwise a named volume
	local src_type dst_type
	if [[ "$src" == */* ]]; then
		src="${src:A}"
		src_type="bind"
	else
		src_type="volume"
	fi

	# Validate src is attached to the container
	local mnt_type mnt_name mnt_source src_attached=0
	while IFS='|' read -r mnt_type mnt_name mnt_source; do
		[[ -z "$mnt_type" ]] && continue
		if   [[ "$src_type" == "volume" && "$mnt_type" == "volume" && "$mnt_name"   == "$src" ]] \
		  || [[ "$src_type" == "bind"   && "$mnt_type" == "bind"   && "$mnt_source" == "$src" ]]; then
			src_attached=1; break
		fi
	done < <(docker inspect -f '{{range .Mounts}}{{.Type}}|{{.Name}}|{{.Source}}{{"\n"}}{{end}}' "$container_name" 2>/dev/null)

	(( src_attached )) || { print_fn -e "'$src' is not attached to container '$container_name'"; return 1; }

	if [[ "$src_type" == "bind" && ! -d "$src" ]]; then
		print_fn -e "Source directory '$src' does not exist"
		return 1
	fi

	if [[ "$dst" == */* ]]; then
		dst="${dst:A}"
		dst_type="bind"
	else
		dst_type="volume"
	fi

	[[ "$src" == "$dst" ]] && { print_fn -e "Source and destination cannot be the same"; return 1; }

	# Prepare destination
	if [[ "$dst_type" == "bind" && ! -d "$dst" ]]; then
		print_fn -ni "Creating destination directory '$dst'..."
		$DRYRUN mkdir -p "$dst" || { print_fn -e "Failed to create '$dst'"; return 1; }
	elif [[ "$dst_type" == "volume" ]]; then
		print_fn -ni "Creating destination volume '$dst'..."
		$DRYRUN docker volume create "$dst" || { print_fn -e "Failed to create volume '$dst'"; return 1; }
	fi

	# Copy data
	print_fn -ni "Copying '$src' ($src_type) → '$dst' ($dst_type)..."
	if [[ "$src_type" == "bind" && "$dst_type" == "bind" ]]; then
		$DRYRUN rsync -aH "${src}/" "${dst}/" || { print_fn -e "rsync failed"; return 1; }
	else
		# docker run handles both named volumes and bind mounts uniformly via -v
		$DRYRUN docker run --rm \
			-v "${src}:/mnt/src:ro" \
			-v "${dst}:/mnt/dst" \
			busybox sh -c "cd /mnt/src && cp -a . /mnt/dst/" \
			|| { print_fn -e "Copy failed"; return 1; }
	fi

	# Verify file layout (skipped in dry-run since nothing was actually copied)
	if [[ -z "$DRYRUN" ]]; then
		print_fn -ni "Verifying file layout..."
		local src_root dst_root src_files dst_files
		if [[ "$src_type" == "bind" ]]; then
			src_root="$src"
		else
			src_root="$(docker volume inspect "$src" -f '{{.Mountpoint}}')" \
				|| { print_fn -e "Cannot inspect volume '$src'"; return 1; }
		fi
		if [[ "$dst_type" == "bind" ]]; then
			dst_root="$dst"
		else
			dst_root="$(docker volume inspect "$dst" -f '{{.Mountpoint}}')" \
				|| { print_fn -e "Cannot inspect volume '$dst'"; return 1; }
		fi

		src_files="$(find "$src_root" -type f | sed "s|^${src_root}/||" | sort)"
		dst_files="$(find "$dst_root" -type f | sed "s|^${dst_root}/||" | sort)"

		if [[ "$src_files" != "$dst_files" ]]; then
			print_fn -e "Verification failed: file layout mismatch"
			return 1
		fi
		print_fn -s "Verification passed"
	fi

	# Remove source or hand off for manual cleanup
	if [[ "$f_keep" ]]; then
		print_fn -w "Source kept. Verify the migration and remove '$src' manually."
	else
		print_fn -ni "Removing source '$src'..."
		if [[ "$src_type" == "bind" ]]; then
			$DRYRUN rm -rf "$src" || { print_fn -e "Failed to remove '$src'"; return 1; }
		else
			$DRYRUN docker volume rm "$src" || { print_fn -e "Failed to remove volume '$src'"; return 1; }
		fi
	fi

	[[ -z "$DRYRUN" ]] && print_fn -s "Migration complete"
}


# ============================================================================
# Plugin setup
# ============================================================================

# Set important environment variables for the proper functioning of docker
docker-set-env


# ============================================================================
# Container-specific commands
# ============================================================================

# Defining simple container aliases
local -a CURRENT_CONTAINERS=(${(f)"$(docker-list)"})
local -a ALIASING_CONTAINERS=(
	caddy cloudflared mollysocket ntfy ollama
)

local -a _available_extensions=()
for container_name in ${ALIASING_CONTAINERS}; do
	if (( ${CURRENT_CONTAINERS[(Ie)$container_name]} )); then
		docker-container-cmd "$container_name"
		_available_extensions+=($ZDOTDIR/extensions/$container_name(NF[1]))
	fi
done
unset ALIASING_CONTAINERS container_name

# Defining more complex aliases
if (( ${CURRENT_CONTAINERS[(Ie)nextcloud]} )); then
	docker-container-cmd -a occ --name nextcloud -u www-data "php occ"
	_available_extensions+=($ZDOTDIR/extensions/nextcloud(NF[1]))
fi
if (( ${CURRENT_CONTAINERS[(Ie)fail2ban]} )); then
	local subcmd
	for subcmd (client python regex server); do
		docker-container-cmd -a fail2ban-$subcmd --name fail2ban fail2ban-$subcmd
	done
	unset subcmd
	_available_extensions+=($ZDOTDIR/extensions/fail2ban(NF[1]))
fi

# Reload extension based on container_name
(( 0 < ${#_available_extensions} )) && zsource -e ${_available_extensions:t}
unset _available_extensions

### Portainer helpers
if (( ${CURRENT_CONTAINERS[(Ie)portainer]} )); then
	# Launch Portainer while restricting its open port
	function portainer-up {
		if (( ! ${+commands[portainer-restrict.sh]} )); then
			print_fn -e "portainer-restrict.sh: executable required but not found"
			return 1
		fi
		docker compose -f $(docker-get-compose portainer) up -d "$@" &&\
			sudo portainer-restrict.sh
	}
fi

unset CURRENT_CONTAINERS
