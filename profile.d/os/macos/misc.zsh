if whatami macOS; then

#######################################
### General
#######################################

### Apps
if [[ -d "/Applications/Godot.app" ]]; then
	alias godot="/Applications/Godot.app/Contents/MacOS/Godot"
fi

### Dev
alias gdb='lldb'

### Other
alias wifi_culprit="sudo log stream | grep -iE --color 'awdl'"

function forget_pkgs {
	local mypkg
	for mypkg in $@; do
		sudo pkgutil --forget $mypkg
	done
}

fi
