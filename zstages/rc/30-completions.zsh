# ============================================================================
# Completions
# ============================================================================
# Only process this part in case omz wasn't loaded
local load_omz
if zstyle -b ':zprofile:submodules:ohmyzsh' loaded load_omz; then
	autoload -Uz compinit

	# Use $ZSH_CACHE_HOME for compdump, keyed by host and zsh version
	local zcompdump="${ZSH_CACHE_HOME}/zcompdump-${SHORT_HOST}-${ZSH_VERSION}"

	# Only run full compinit if dump is missing or older than 24 hours
	if [[ ! -f "$zcompdump" || $(( $(date +%s) - $(date +%s -r "$zcompdump") )) -gt 86400 ]]; then
		compinit -i -d "$zcompdump"
		# Compile dump for faster loading next time
		[[ ! -f "${zcompdump}.zwc" || "$zcompdump" -nt "${zcompdump}.zwc" ]] &&
			zcompile "$zcompdump" &>/dev/null &
	else
		compinit -C -d "$zcompdump"
	fi
fi

# ============================================================================
# Bash completions
# ============================================================================
# Bash modules & autocompletion (for programs which contain only bash completions)
if [[ -d "$XDG_DATA_HOME"/bash-completion/completions ]]; then
	local f_bashcomp
	autoload bashcompinit && bashcompinit &&
	for f_bashcomp in "$XDG_DATA_HOME"/bash-completion/completions/*(-N.); do
		source "$f_bashcomp"
	done
fi
