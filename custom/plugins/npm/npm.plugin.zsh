(( ${+commands[npm]} )) || return 0

if [[ ! -f "$NPM_CONFIG_USERCONFIG" ]] || ! file_contents_in "$NPM_CONFIG_USERCONFIG" "$ZDOTDIR/conf/npm/.npmrc"; then
	cat "$ZDOTDIR/conf/npm/.npmrc" >> "$NPM_CONFIG_USERCONFIG"
fi

# Add global node_modules to PATH
addpath 1 "$(npm config get prefix)/bin"

# Add global node_modules to MANPATH
(( ${+MANPATH} )) && addvar MANPATH "$(npm config get prefix)/share"

# Add npm completion
command rm -f "${ZSH_CACHE_DIR:-$ZSH/cache}/npm_completion"

_npm_completion() {
	local si=$IFS
	compadd -- $(COMP_CWORD=$((CURRENT-1)) \
		COMP_LINE=$BUFFER \
		COMP_POINT=0 \
		npm completion -- "${words[@]}" \
		2>/dev/null)
	IFS=$si
}
compdef _npm_completion npm
