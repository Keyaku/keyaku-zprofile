#######################################
### Python
#######################################

if [[ -o login ]]; then

### Custom user venv
if [[ -d "${XDG_DATA_HOME}"/pyvenv && -f "${XDG_DATA_HOME}"/pyvenv/pyvenv.cfg ]] && (( ! ${+VIRTUAL_ENV} )); then
	source "${XDG_DATA_HOME}"/pyvenv/bin/activate
fi

fi
