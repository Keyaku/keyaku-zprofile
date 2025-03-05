(( ${+commands[npm]} )) || return 0

# If NPM_CONFIG_USERCONFIG is set, check if file exists and if it contains a given configuration
if (( ${+NPM_CONFIG_USERCONFIG} )) && \grep -Eq 'prefix = ${XDG_DATA_HOME}/npm' "$NPM_CONFIG_USERCONFIG"; then
	diff -BNPZbrw --changed-group-format='%>' --unchanged-group-format='' --to-file "$ZDOTDIR/conf/npm/.npmrc" "$NPM_CONFIG_USERCONFIG" > "$XDG_CACHE_HOME"/zsh/npmrc.diff
	cat "$XDG_CACHE_HOME"/zsh/npmrc.diff >> "$NPM_CONFIG_USERCONFIG"
	rm -f "$XDG_CACHE_HOME"/zsh/npmrc.diff
fi

_npm_pfx="$(npm config get prefix)"

# Prepend global node_modules to PATH
(( ${(v)+path[(I)"$_npm_pfx"/bin]} )) || path=("$_npm_pfx/bin" $path)

# Append global node_modules to MANPATH
if (( ${+MANPATH} )) && [[ "$MANPATH" =~ ":?$_npm_pfx/share:?" ]]; then
	MANPATH+=":$_npm_pfx/share"
fi

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
