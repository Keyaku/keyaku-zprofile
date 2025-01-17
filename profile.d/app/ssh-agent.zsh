function ssh-agent-start {
	# Check for a currently running instance of the agent
	local RUNNING_AGENT="`ssh-agent-pids | wc -l | tr -d '[:space:]'`"
	if [[ $RUNNING_AGENT -eq 0 ]]; then
		# Launch a new instance of the agent
		ssh-agent -s | sed 's/echo.*//' &> ${SSH_HOME:-$HOME/.ssh}/ssh-agent
	fi
	. `cat ${SSH_HOME:-$HOME/.ssh}/ssh-agent`
}

function ssh-agent-stop {
	killall ssh-agent
}

function ssh-agent-pids {
	ps -ax | grep 'ssh-agent -s' | grep -v grep
}
