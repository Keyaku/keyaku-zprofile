##############################################################################
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
##############################################################################

# ============================================================================
# Benchmark Setup
# ============================================================================
# Track loading time if ZSH_PROFILE_BENCHMARK is set
if (( ${ZSH_PROFILE_BENCHMARK} )); then
	zmodload zsh/datetime
	local t_zsh_start=$EPOCHREALTIME
fi

# ============================================================================
# Stage 1: Load zlogin stage files
# ============================================================================

_zsh_source_dir "${ZDOTDIR}/zstages/login" "login"

# ============================================================================
# Benchmark Output
# ============================================================================
# Benchmark output for this stage
if (( ${ZSH_PROFILE_BENCHMARK} )); then
	local t_end=$EPOCHREALTIME
	local t_total=$(( t_end - t_zsh_start ))
	print -u2 "========================================="
	print -u2 "[TOTAL] $(is_sourced_by) stage took ${t_total}s"
	print -u2 "========================================="
	print -u2 ""
	unset t_start t_end t_total
fi

# vim: ft=zsh ts=4 sw=4 et
