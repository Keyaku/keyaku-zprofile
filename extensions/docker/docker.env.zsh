(( $+commands[docker] && ! $+commands[podman] )) || return

# Standardized $0 handling
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#zero-handling
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

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
