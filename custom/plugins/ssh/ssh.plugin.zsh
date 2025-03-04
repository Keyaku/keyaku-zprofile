(( ${+commands[ssh] })) || return

function is_ssh_dir {
	local ssh_dir="$1"
	[[ -f "$ssh_dir/config" || -d "$ssh_dir/config.d" ]] || \
	[[ -f "$ssh_dir/known_hosts" || -d "$ssh_dir/known_hosts.d" ]] || \
	[[ -f "$ssh_dir/authorized_keys" ]]
}

if (( ! ${+SSH_HOME} )) || [[ ! -d "$SSH_HOME" ]]; then
	# Define root directory for .ssh. The first found will be picked
	for SSH_HOME in "${XDG_CONFIG_HOME}"/ssh "${XDG_DATA_HOME}"/ssh "${XDG_STATE_HOME}"/ssh; do
		if [[ -d "$SSH_HOME" ]] && is_ssh_dir "$SSH_HOME"; then
			break
		fi
	done
fi

unfunction is_ssh_dir

# Pick default value if unset
SSH_HOME="${SSH_HOME:-"$HOME"/.ssh}"

# If $HOME/.ssh exists and is not defined as SSH_HOME, move its contents
if [[ -d ~$USER/.ssh ]] && [[ "$SSH_HOME" != ~$USER/.ssh ]]; then
	rsync -Praz ~$USER/.ssh/ "${SSH_HOME}" &>/dev/null
	if (( ! $? )); then
		rm -r ~$USER/.ssh
	fi
fi

############################################################
# Take all host sections in config (and config.d/*) and offer them for
# completion as hosts (e.g. for ssh, rsync, scp and the like)
# Filter out wildcard host sections.
if [[ "$(echo "${SSH_HOME}/config"{,.d/*.conf}(N))" ]]; then
	_ssh_hosts=($(
		\grep -E '^Host[^*]*' "${SSH_HOME}/config"{,.d/*.conf} |\
		awk '{for (i=2; i<=NF; i++) print $i}' |\
		sort -u |\
		grep -v '\*'
	))
	zstyle ':completion:*:hosts' hosts $_ssh_hosts
	unset _ssh_hosts
fi

############################################################
# Remove host key from known hosts based on a host section
# name from config
function ssh_rmhkey {
	local ssh_host="$1"
	[[ -z "$ssh_host" ]] && return
	ssh-keygen -R $(\grep -A10 "$ssh_host" "$SSH_HOME"/config{,.d/*.conf} | sed -nE '/HostName/{s/.*HostName\s+(.+?)/\1/pi;q}')
}
compctl -k hosts ssh_rmhkey

############################################################
# Load SSH key into agent
function ssh_load_key() {
	local key="$1"
	[[ -z "$key" ]] && return
	local keyfile="${SSH_HOME}/$key"
	local keysig=$(ssh-keygen -l -f "$keyfile")
	if ( ! ssh-add -l | \grep -q "$keysig" ); then
		ssh-add "$keyfile"
	fi
}

############################################################
# Remove SSH key from agent
function ssh_unload_key {
	local key="$1"
	[[ -z "$key" ]] && return
	local keyfile="${SSH_HOME}/$key"
	local keysig=$(ssh-keygen -l -f "$keyfile")
	if ( ssh-add -l | \grep -q "$keysig" ); then
		ssh-add -d "$keyfile"
	fi
}
