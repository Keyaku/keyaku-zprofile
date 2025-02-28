#######################################
### NPM (Node.js)
#######################################

(( $+commands[npm] )) || return

if [[ ! -f "$NPM_CONFIG_USERCONFIG" ]] || file_contents_in "$NPM_CONFIG_USERCONFIG" "$ZDOTDIR/conf/npm/.npmrc"; then
	cat "$ZDOTDIR/conf/npm/.npmrc" >> "$NPM_CONFIG_USERCONFIG"
fi

# Add global node_modules to PATH
addpath 1 "$(npm config get prefix)/bin"

# Add global node_modules to MANPATH
(( ${+MANPATH} )) && addvar MANPATH "$(npm config get prefix)/share"
