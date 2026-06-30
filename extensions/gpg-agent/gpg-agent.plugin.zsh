(( ${+commands[gpg-agent]} )) || return

# GNUPGHOME is exported and provisioned in gpg.env.zsh (env stage, all shells);
# nothing to repeat here.

# Ensure pinentry is configured. Pure-zsh substring test avoids a grep fork on
# every interactive shell (the conf file is tiny, so $(<file) is cheap).
() {
	local conf="$GNUPGHOME/gpg-agent.conf"
	[[ -f "$conf" && "$(<$conf)" == *'pinentry-program /usr/bin/pinentry'* ]] && return
	print -r -- 'pinentry-program /usr/bin/pinentry' >> "$conf"
}

# Ensure the agent is up, once per session. gpg-agent.socket is socket-activated
# (static), so an explicit start is belt-and-suspenders; the exported marker keeps
# nested interactive shells from re-running the ~3.5ms `systemctl is-active` probe.
if [[ -z "$_ZSH_GPG_AGENT_ENSURED" ]]; then
	export _ZSH_GPG_AGENT_ENSURED=1
	if has_user_systemd && ! systemctl --user -q is-active gpg-agent.socket; then
		systemctl --user -q start gpg-agent
	fi
fi

# tty handling for pinentry, folded in from OMZ's gpg-agent plugin (which we no
# longer load — its only other job was wiring gpg-agent's SSH support via two
# `gpgconf` probes per shell, ~4ms, unused here since SSH_AUTH_SOCK comes from the
# dedicated ssh-agent.service).
export GPG_TTY=$TTY
(( ${+commands[add-zsh-hook]} )) || autoload -Uz add-zsh-hook
if (( ! ${+functions[_gpg_agent_update_tty]} )); then
	# Keep gpg-agent's notion of the active tty current so pinentry targets the
	# terminal the command was launched from.
	function _gpg_agent_update_tty {
		gpg-connect-agent updatestartuptty /bye &>/dev/null
	}
	add-zsh-hook preexec _gpg_agent_update_tty
fi
