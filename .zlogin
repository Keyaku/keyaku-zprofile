#####################################################################
#                            .zlogin
#
# File loaded 4th && if [[ -o login ]]
#
# Used for executing user's commands at ending of initial progress,
# will be read when starting as a login shell.
# Typically used to autostart command line utilities.
# Should not be used to autostart graphical sessions,
# as at this point the session might contain configuration
# meant only for an interactive shell.
#####################################################################

# Track loading time if ZSH_PROFILE_BENCHMARK is set
typeset -g _zsh_profile_start_time
if [[ -n "${ZSH_PROFILE_BENCHMARK}" ]]; then
	zmodload zsh/datetime
	_zsh_profile_start_time=$EPOCHREALTIME
fi

### Source login stage
_zsh_source_dir "${ZDOTDIR}/zstages/login" "login"

# Benchmark output for this stage
if [[ -n "${ZSH_PROFILE_BENCHMARK}" ]]; then
	local t_end=$EPOCHREALTIME
	local total=$(( t_end - _zsh_profile_start_time ))
	print -u2 "[TOTAL] $(is_sourced_by) stage took ${total}s"
fi
