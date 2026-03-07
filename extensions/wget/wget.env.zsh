(( ${+commands[wget]} )) || return

export WGETRC="${XDG_CONFIG_HOME}/wgetrc"
[[ -d "${XDG_DATA_HOME}"/wget ]] || mkdir -p "${XDG_DATA_HOME}"/wget

if ! \grep -qw "hsts-file=${XDG_DATA_HOME}/wget/hsts" "${XDG_CONFIG_HOME}"/wgetrc; then
	echo "hsts-file=${XDG_DATA_HOME}/wget/hsts" >> "${XDG_CONFIG_HOME}"/wgetrc
fi
