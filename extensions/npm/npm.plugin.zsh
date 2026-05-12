(( ${+commands[npm]} )) || return

# Resolve the global prefix directly from the XDG layout. The preset .npmrc
# pins `prefix = ${XDG_DATA_HOME}/npm`, so we don't need to spawn `npm config
# get prefix` (a node fork costs ~100-300ms on cold start).
local _npm_pfx="${XDG_DATA_HOME:-$HOME/.local/share}/npm"

# Add global node_modules to PATH (typeset -U keeps it dedup'd).
addpath 1 "$_npm_pfx/bin"

# Append npm's share/ to MANPATH only when MANPATH is already set (an unset
# MANPATH lets man(1) fall back to its own default search, which we don't
# want to clobber).
if [[ -v MANPATH && ":$MANPATH:" != *":$_npm_pfx/share:"* ]]; then
	MANPATH="$MANPATH:$_npm_pfx/share"
fi

# One-shot: merge the preset .npmrc into the user config. The fixed-string
# grep on a 3-line file is ~1ms and short-circuits once synced.
if [[ -f "$NPM_CONFIG_USERCONFIG" ]] && \
	! \grep -Fq 'prefix = ${XDG_DATA_HOME}/npm' "$NPM_CONFIG_USERCONFIG"; then
	diff -BNPZbrw \
		--changed-group-format='%>' \
		--unchanged-group-format='' \
		--to-file "$ZDOTDIR/conf/home/npm/.npmrc" \
		"$NPM_CONFIG_USERCONFIG" \
		>> "$NPM_CONFIG_USERCONFIG"
fi
