#######################################
# Backup systems
#######################################
if command-has borg; then

if [[ -f "$(whereis borg-backup.sh | awk '{ print $2 }')" ]]; then
	alias borg-backup="$(whereis borg-backup.sh | awk '{ print $2 }')"
	alias borg-backup-edit="vim borg-backup"
fi

fi


#######################################
# ds4drv
#######################################

if command-has ds4drv; then

function ds4drv-check {
	local FILE_pid="$XDG_CACHE_HOME/ds4drv/ds4drv.pid"
	local pid

	# Look for PID from file
	if [[ -f "$FILE_pid" ]]; then
		pid=$(cat "$FILE_pid")
	else
	# Otherwise, look via pgrep
		pid=$(pgrep ds4drv)
	fi

	# Check if pid is set
	if [[ -z "$pid" ]] || ! kill -0 $pid &>/dev/null; then
		echo "No ds4drv instance running" >/dev/stderr
		return 1
	elif [[ $pid -eq 0 ]]; then
		echo "Invalid pid for ds4drv: $pid" >/dev/stderr
		return 2
	fi

	echo $pid
}

function ds4drv-start {
	local PATH_cache="$XDG_CACHE_HOME/ds4drv"
	local FILE_pid="$PATH_cache/ds4drv.pid"
	local FILE_log="$PATH_cache/ds4drv.log"

	# If the PID file exists and there's no actual process, delete it
	if [[ -f "$FILE_pid" ]] && ! ds4drv-check &>/dev/null; then
		rm "$FILE_pid"
	fi

	ds4drv --config "$XDG_CONFIG_HOME/ds4drv/ds4drv.conf" --daemon-log "$FILE_log" --daemon-pid "$FILE_pid"
}

function ds4drv-stop {
	local FILE_log="$XDG_CACHE_HOME/ds4drv/ds4drv.log"
	local pid=$(ds4drv-check)

	if [[ $pid -gt 0 ]]; then
		echo "[info][daemon] Shutting down ds4drv" | tee -a -- "$FILE_log"
		killall ds4drv
	fi
}

fi


#######################################
# GNUPG
#######################################
function gpg-fix-perms {
	local homedir=${1:-$GNUPGHOME}
	if [[ ! -d "$homedir" ]]; then
		echo "Unable to fix permissions on invalid directory: '$homedir'"
		return 1
	fi
	find "$homedir" -type f -exec chmod 600 {} \; # Set 600 for files
	find "$homedir" -type d -exec chmod 700 {} \; # Set 700 for directories
}
