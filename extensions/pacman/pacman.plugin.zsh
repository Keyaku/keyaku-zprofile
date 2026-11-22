(( ${+commands[pacman]} )) || return

# On-demand bin rehash: the pacman hook touches this file after every
# transaction, so rehash whenever its mtime changes. zstat reads the mtime
# without forking, unlike `date -r` (which ran at startup and every prompt).
zmodload -F zsh/stat b:zstat
typeset -g _zsh_pacman_hook="${TERMUX__PREFIX:-}/var/cache/zsh/pacman"
typeset -gi _zshcache_time=0
() {
	local -a mtime
	zstat -A mtime +mtime -- "$_zsh_pacman_hook" 2>/dev/null && _zshcache_time=$mtime[1]
}
(( ${+functions[add-zsh-hook]} )) || autoload -Uz add-zsh-hook

if (( ! ${precmd_functions[(I)_rehash_precmd]} )); then
	_rehash_precmd() {
		local -a mtime
		zstat -A mtime +mtime -- "$_zsh_pacman_hook" 2>/dev/null || return 0
		if (( mtime[1] != _zshcache_time )); then
			rehash
			_zshcache_time=$mtime[1]
		fi
	}
	add-zsh-hook -Uz precmd _rehash_precmd
fi
