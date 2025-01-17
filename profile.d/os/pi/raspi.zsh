if whatami pi; then

#######################################
# SYSTEM
#######################################
# System temperature
function cputemp {
	local tempC=0

	if [[ -f "/sys/class/thermal/thermal_zone0/temp" ]]; then
		tempC=$(($(cat /sys/class/thermal/thermal_zone0/temp)/1000))
	fi

	echo "CPU: ${tempC}ºC"
}

function gputemp {
	local tempC=0

	if tempC=$(vcgencmd measure_temp); then
		tempC=${tempC:5:2}
	fi

	echo "GPU: ${tempC}ºC"
}


# Monitoring tool
function monit_en {
	local DIR_monit="/etc/monit"
	local args=($@)

	if [ $# -eq 0 ]; then
		printf "Your choices are: "
		ls -1p "$DIR_monit/conf-available" | xargs echo | sed 's/,/ /g'
		echo "Which services do you want to monitor?"
		read
		args=($(echo $REPLY | tr " " "\n"))
	fi
	for arg in $args; do
		if [ -f "$DIR_monit/conf-enabled/$arg" ]; then
			echo "Service $arg already being monitored"
		else
			sudo ln -s "$DIR_monit/conf-available/$arg" "$DIR_monit/conf-enabled/"
			echo "To activate the new configuration, you need to run:"
			echo "  sudo systemctl reload monit"
		fi
	done
}

function monit_dis {
	local DIR_monit="/etc/monit"
	local args=($@)

	if [ $# -eq 0 ]; then
		printf "Your choices are: "
		ls -1p "$DIR_monit/conf-enabled" | xargs echo | sed 's/,/ /g'
		echo "Which services do you want to stop monitoring?"
		read
		args=($(echo $REPLY | tr " " "\n"))
	fi
	for arg in $args; do
		if [ ! -f "$DIR_monit/conf-enabled/$arg" ]; then
			echo "Service $arg not being monitored"
		else
			sudo rm -f "$DIR_monit/conf-enabled/$arg"
			echo "To activate the new configuration, you need to run:"
			echo "  sudo systemctl reload monit"
		fi
	done
}

fi
