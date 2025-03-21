(( ${+commands[pacman]} )) || return 0

# On-demand bin rehash
_zshcache_time="$(date +%s%N)"
(( ${+commands[add-zsh-hook]} )) || autoload -Uz add-zsh-hook

if (( ! ${+precmd_functions[_rehash_precmd]} )); then
	_rehash_precmd() {
		if [[ -a /var/cache/zsh/pacman ]]; then
			local paccache_time="$(date -r /var/cache/zsh/pacman +%s%N)"
			if (( _zshcache_time < paccache_time )); then
				rehash
				_zshcache_time="$paccache_time"
			fi
		fi
	}
	add-zsh-hook -Uz precmd _rehash_precmd
fi
