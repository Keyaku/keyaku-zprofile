(( ${+commands[npm]} )) || return

# Set the npm user config envvar to the XDG specification
export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME}"/npm/.npmrc
[[ -f "$NPM_CONFIG_USERCONFIG" ]] || touch "$NPM_CONFIG_USERCONFIG"
