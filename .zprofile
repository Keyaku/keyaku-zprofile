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

# Standardized $0 handling
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#zero-handling
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

# Track loading time if ZSH_PROFILE_BENCHMARK is set
typeset -g _zsh_profile_start_time
if [[ -n "${ZSH_PROFILE_BENCHMARK}" ]]; then
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
	print -u2 "[TOTAL] ${0:t} stage took ${total}s"
fi
