if whatami macOS; then

##############################################
### System tweaks
##############################################
function awdl_stop {
	while :; do
		if ifconfig | pcregrep -M -o '^[^\t:]+(?=:([^\n]|\n\t)*status: active)' | grep awdl0; then
			echo "Shutting down awdl0..."
			sudo ifconfig awdl0 down
		fi
		sleep 5
	done
}

##############################################
### Dock settings
##############################################
function dock_hide {
	defaults write com.apple.dock autohide -bool true && killall Dock
	defaults write com.apple.dock autohide-delay -float 1000 && killall Dock
	defaults write com.apple.dock no-bouncing -bool TRUE && killall Dock
}

function dock_show {
	defaults write com.apple.dock autohide -bool false && killall Dock
	defaults delete com.apple.dock autohide-delay && killall Dock
	defaults write com.apple.dock no-bouncing -bool FALSE && killall Dock
}


### Locale
LC_ALL="UTF-8",
LANG="en_GB.UTF-8"

fi
