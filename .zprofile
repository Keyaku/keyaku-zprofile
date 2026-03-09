#####################################################################
#                            .zprofile
#
# File loaded 2nd && if [[ -o login ]]
#
# Used for executing user's commands at start,
# will be read when starting as a *login shell*.
# Typically used to autostart graphical sessions
# and to set session-wide environment variables.
#####################################################################

# Track loading time if ZSH_PROFILE_BENCHMARK is set
if [[ -n "${ZSH_PROFILE_BENCHMARK}" ]]; then
	typeset -g _zsh_profile_start_time
	zmodload zsh/datetime
	_zsh_profile_start_time=$EPOCHREALTIME
fi

### Source path/session functions
_zsh_source_dir "${ZDOTDIR}/lib/login" "lib/login"

### Source profile stage
_zsh_source_dir "${ZDOTDIR}/zstages/profile" "profile"

# Benchmark output for this stage
if [[ -n "${ZSH_PROFILE_BENCHMARK}" ]]; then
	local t_end=$EPOCHREALTIME
	local total=$(( t_end - _zsh_profile_start_time ))
	print -u2 "[TOTAL] $(is_sourced_by) stage took ${total}s"
fi
