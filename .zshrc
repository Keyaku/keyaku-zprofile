##############################################################################
#                            .zshrc
#
# File loaded 3rd && if [[ -o interactive ]]
#
# Used for setting user's interactive shell configuration
# and executing commands, will be read when starting
# as an *interactive shell*.
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
# Stage 1: Load custom functions (fpath setup)
# ============================================================================
# This needs to happen EARLY because:
# 1. Stage files may depend on these functions.
# 2. Functions are autoloaded (lazy), so this is just fpath setup.
# 3. OMZ and extensions may also need these functions available.

export ZSH_CUSTOM="$ZDOTDIR/custom"
autoload -Uz "$ZSH_CUSTOM"/functions/{,.}**/zsource(.N) && zsource -f

# ============================================================================
# Stage 2: Load interactive libraries
# ============================================================================
# These are helper functions/utilities for interactive shells.
# Load before stage files so they can use these utilities.

_zsh_source_dir "${ZDOTDIR}/lib/interactive" "lib/interactive"

# ============================================================================
# Stage 3: Load zshrc stage files
# ============================================================================

# Main configuration files for the interactive shell
_zsh_source_dir "${ZDOTDIR}/zstages/rc" "rc"

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
	unset t_start t_end t_total
fi

# vim: ft=zsh ts=4 sw=4 et
