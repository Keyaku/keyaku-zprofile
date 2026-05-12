(( ${+commands[npm]} )) || return

# Set the npm user config envvar to the XDG specification
export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME}"/npm/.npmrc
[[ -d "${XDG_CONFIG_HOME}"/npm ]] || mkdir -p "${XDG_CONFIG_HOME}"/npm
[[ -f "$NPM_CONFIG_USERCONFIG" ]] || touch "$NPM_CONFIG_USERCONFIG"
