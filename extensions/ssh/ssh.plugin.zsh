(( ${+commands[ssh]} )) || return

############################################################
# Take all host sections in config (and config.d/*) and offer them for
# completion as hosts (e.g. for ssh, rsync, scp and the like)
# Filter out wildcard host sections.
local -a _ssh_confs=("${SSH_HOME}/config"{,.d/*.conf}(N))
if (( ${#_ssh_confs} )); then
	# Pure-zsh parse of `Host` lines — avoids a grep|awk|sort|grep fork chain on
	# every interactive shell. Collect every non-wildcard host pattern.
	local -aU _ssh_hosts=()
	local _conf _line w
	local -a _words
	for _conf in $_ssh_confs; do
		while IFS= read -r _line; do
			_words=(${(z)_line})
			[[ "${(L)_words[1]}" == host ]] || continue
			for w in ${_words[2,-1]}; do
				[[ "$w" == *'*'* ]] || _ssh_hosts+="$w"
			done
		done < $_conf
	done
	(( ${#_ssh_hosts} )) && zstyle ':completion:*:hosts' hosts $_ssh_hosts
fi

############################################################
# Remove host key from known hosts based on a host section
# name from config
function ssh_rmhkey {
	local ssh_host="$1"
	[[ -z "$ssh_host" ]] && return
	ssh-keygen -R $(grep -A10 "$ssh_host" "$SSH_HOME"/config{,.d/*.conf}(N) | sed -nE '/HostName/{s/.*HostName\s+(.+?)/\1/pi;q}')
}
compctl -k hosts ssh_rmhkey

############################################################
# Load SSH key into agent
function ssh_load_key() {
	local key="$1"
	[[ -z "$key" ]] && return
	local keyfile="${SSH_HOME}/$key"
	local keysig=$(ssh-keygen -l -f "$keyfile")
	if ( ! ssh-add -l | grep -q "$keysig" ); then
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
	if ( ssh-add -l | grep -q "$keysig" ); then
		ssh-add -d "$keyfile"
	fi
}
