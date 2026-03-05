#######################################
### XDG variables
#######################################

### User Directories
export XDG_CACHE_HOME=$HOME/.local/cache
export XDG_CONFIG_HOME=$HOME/.local/config
export XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
export XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}

# Load user-dirs if available
if [[ -s $XDG_CONFIG_HOME/user-dirs.dirs ]]; then
	source "$XDG_CONFIG_HOME/user-dirs.dirs"
# user-dirs fallback (only if running a DE. Otherwise, not much interest in having these set)
elif [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
	[[ -z $XDG_DESKTOP_DIR && -d $HOME/Desktop ]] && export XDG_DESKTOP_DIR=$HOME/Desktop
	[[ -z $XDG_DOCUMENTS_DIR && -d $HOME/Documents ]] && export XDG_DOCUMENTS_DIR=$HOME/Documents
	[[ -z $XDG_DOWNLOAD_DIR && -d $HOME/Downloads ]] && export XDG_DOWNLOAD_DIR=$HOME/Downloads
	[[ -z $XDG_MUSIC_DIR && -d $HOME/Music ]] && export XDG_MUSIC_DIR=$HOME/Music
	[[ -z $XDG_PICTURES_DIR && -d $HOME/Pictures ]] && export XDG_PICTURES_DIR=$HOME/Pictures
	[[ -z $XDG_PUBLICSHARE_DIR && -d $HOME/Public ]] && export XDG_PUBLICSHARE_DIR=$HOME/Public
	[[ -z $XDG_TEMPLATES_DIR && -d $HOME/Templates ]] && export XDG_TEMPLATES_DIR=$HOME/Templates
	[[ -z $XDG_VIDEOS_DIR && -d $HOME/Videos ]] && export XDG_VIDEOS_DIR=$HOME/Videos
fi
