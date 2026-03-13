(( ${+commands[wget]} )) || return

export WGETRC="${XDG_CONFIG_HOME}/wgetrc"
[[ -d "${XDG_DATA_HOME}"/wget ]] || mkdir -p "${XDG_DATA_HOME}"/wget

local hsts_entry="hsts-file=${XDG_DATA_HOME}/wget/hsts"
[[ -f "$WGETRC" && "${$(<$WGETRC)}" == *"$hsts_entry"* ]] || echo "$hsts_entry" >> "$WGETRC"
