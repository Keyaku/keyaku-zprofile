(( ${+commands[npm]} )) || return

# Check if npm config contains a given configuration; if not, add preset configuration to it
if ! \grep -Eq 'prefix = \${XDG_DATA_HOME}/npm' "$NPM_CONFIG_USERCONFIG"; then
	diff -BNPZbrw \
		--changed-group-format='%>' \
		--unchanged-group-format='' \
		--to-file "$ZDOTDIR/conf/npm/.npmrc" \
		"$NPM_CONFIG_USERCONFIG" \
		>> "$NPM_CONFIG_USERCONFIG"
fi

local _npm_pfx="$(npm config get prefix)"

# Prepend global node_modules to PATH
(( ${(v)+path[(I)"$_npm_pfx"/bin]} )) || path=("$_npm_pfx/bin" $path)

# Append global node_modules to MANPATH
if [[ -v MANPATH && ! "${MANPATH//:/ }" =~ " $_npm_pfx/share" ]]; then
	MANPATH+=":$_npm_pfx/share"
fi
