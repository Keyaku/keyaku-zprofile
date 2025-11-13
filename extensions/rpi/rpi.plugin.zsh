whatami pi || return

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
