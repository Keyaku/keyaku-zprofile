(( ${+commands[pacman]} )) || return

# On-demand bin rehash
_zshcache_time="$(date +%s%N)"
(( ${+commands[add-zsh-hook]} )) || autoload -Uz add-zsh-hook

if (( ! ${+precmd_functions[_rehash_precmd]} )); then
	_rehash_precmd() {
		local cache_hook="${TERMUX__PREFIX:-}/var/cache/zsh/pacman"
		if [[ -a "$cache_hook" ]]; then
			local paccache_time="$(date -r "$cache_hook" +%s%N)"
			if (( _zshcache_time < paccache_time )); then
				rehash
				_zshcache_time="$paccache_time"
			fi
		fi
	}
	add-zsh-hook -Uz precmd _rehash_precmd
fi
