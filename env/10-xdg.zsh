#######################################
### XDG variables
#######################################

### User Directories
export XDG_CACHE_HOME=$HOME/.local/cache
export XDG_CONFIG_HOME=$HOME/.local/config
export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
export XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}
# Set XDG_RUNTIME_DIR for Termux
if (( ${+TERMUX_VERSION} )); then
	export XDG_RUNTIME_DIR="${${:-$HOME/../usr/var/run/$UID}:P}"
fi

### System directories
# FIXME: Set these appropriately with addvar and if Flatpak is available
# typeset -a xdg_data_dirs=("${XDG_DATA_HOME}"/flatpak/exports/share "/var/lib/flatpak/exports/share" "${XDG_DATA_HOME}")
# for data_dir in ${xdg_data_dirs}; do
# 	if [[ -d "$data_dir" ]] && ! [[ "$XDG_DATA_DIRS" =~ (^|:)"$data_dir"/?(:|$) ]]; then
# 		XDG_DATA_DIRS="$data_dir":"$XDG_DATA_DIRS"
# 	fi
# done
# unset data_dir xdg_data_dirs
# typeset -a xdg_config_dirs=("${XDG_CONFIG_HOME}")
# for config_dir in ${xdg_data_dirs}; do
# 	if [[ -d "$config_dir" ]] && ! [[ "$XDG_CONFIG_DIRS" =~ (^|:)"$config_dir"/?(:|$) ]]; then
# 		XDG_CONFIG_DIRS="$config_dir":"$XDG_CONFIG_DIRS"
# 	fi
# done
# unset config_dir xdg_config_dirs
