(( ${+commands[npm]} )) || return 0

if [[ ! -f "$NPM_CONFIG_USERCONFIG" ]] || ! file_contents_in "$NPM_CONFIG_USERCONFIG" "$ZDOTDIR/conf/npm/.npmrc"; then
	cat "$ZDOTDIR/conf/npm/.npmrc" >> "$NPM_CONFIG_USERCONFIG"
fi

_npm_pfx="$(npm config get prefix)"

# Prepend global node_modules to PATH
(( ${(v)+path[(I)"$_npm_pfx"/bin]} )) || path=("$_npm_pfx/bin" $path)

# Append global node_modules to MANPATH
(( ${+MANPATH} )) && addvar MANPATH "$_npm_pfx/share"

unset _npm_pfx

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
