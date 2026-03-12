##############################################################################
#                            .zshenv
#
# File loaded 1st.
#
# Used for setting user's environment variables;
# it should not contain commands that produce output
# or assume the shell is attached to a TTY.
# When this file exists, it will _always_ be read.
##############################################################################

# Uncomment the following lines to enable the benchmark or debug flags
# ZSH_PROFILE_BENCHMARK=1
# ZSH_PROFILE_DEBUG=1

# Enable debug mode if ZSH_PROFILE_DEBUG is set
[[ -n "${ZSH_PROFILE_DEBUG}" ]] && setopt XTRACE

# ============================================================================
# Benchmark Setup
# ============================================================================
# Track loading time if ZSH_PROFILE_BENCHMARK is set
if [[ -n "${ZSH_PROFILE_BENCHMARK}" ]]; then
	zmodload zsh/datetime
	local t_zsh_start=$EPOCHREALTIME
fi

# ============================================================================
# Helper functions
# ============================================================================

# Helper function for safe sourcing with error handling
_zsh_source_file() {
	local zsh_file=$1
	local stage=${2:-${1:t}}

	[[ -f "$zsh_file" ]] || { print -u2 "Warning: File not found: $zsh_file"; return 1; }
	[[ -r "$zsh_file" ]] || { print -u2 "Warning: File not readable: $zsh_file"; return 1; }

	local t_start
	[[ -n "$ZSH_PROFILE_BENCHMARK" ]] && t_start=$EPOCHREALTIME
	source "$zsh_file"
	[[ -n "$ZSH_PROFILE_BENCHMARK" ]] && print -u2 "[$stage] ${zsh_file:t} took $(( EPOCHREALTIME - t_start ))s"
}

# Helper function for sourcing directories
_zsh_source_dir() {
	local target_dir=$1
	local stage=${2:-unknown}
	local pattern=${3:-"*.zsh"}

	[[ -d "$target_dir" ]] || return 1

	# Use glob qualifiers: N (null_glob), . (regular LIST_files), o (order by name)
	local zsh_file
	for zsh_file in "${target_dir}"/${~pattern}(N.on); do
		_zsh_source_file "$zsh_file" "$stage"
	done
}

# ============================================================================
# Stage 1: Load core library functions
# ============================================================================
# These are fundamental utilities needed everywhere.

_zsh_source_dir "${ZDOTDIR}/lib/core" "lib/core"

# ============================================================================
# Stage 2: Load zshenv stage files
# ============================================================================

_zsh_source_dir "${ZDOTDIR}/zstages/env" "env"

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
