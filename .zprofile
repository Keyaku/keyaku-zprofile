##############################################################################
#                            .zprofile
#
# File loaded 2nd && if [[ -o login ]]
#
# Used for executing user's commands at start,
# will be read when starting as a *login shell*.
# Typically used to autostart graphical sessions
# and to set session-wide environment variables.
##############################################################################

# ============================================================================
# Benchmark Setup
# ============================================================================
# Track loading time if ZSH_PROFILE_BENCHMARK is set
if [[ -n "${ZSH_PROFILE_BENCHMARK}" ]]; then
	zmodload zsh/datetime
	local t_zsh_start=$EPOCHREALTIME
fi

# ============================================================================
# Stage 1: Load login libraries
# ============================================================================

_zsh_source_dir "${ZDOTDIR}/lib/login" "lib/login"

# ============================================================================
# Stage 2: Load zprofile stage files
# ============================================================================

_zsh_source_dir "${ZDOTDIR}/zstages/profile" "profile"

# ============================================================================
# Benchmark Output
# ============================================================================
# Benchmark output for this stage
if [[ -n "${ZSH_PROFILE_BENCHMARK}" ]]; then
	local t_end=$EPOCHREALTIME
	local t_total=$(( t_end - t_zsh_start ))
	print -u2 "========================================="
	print -u2 "[TOTAL] $(is_sourced_by) stage took ${t_total}s"
	print -u2 "========================================="
	print -u2 ""
fi

# vim: ft=zsh ts=4 sw=4 et
