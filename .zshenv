#####################################################################
#                            .zshenv
#
# File loaded 1st.
#
# Used for setting user's environment variables;
# it should not contain commands that produce output
# or assume the shell is attached to a TTY.
# When this file exists it will _always_ be read.
#####################################################################

# Enable debug mode if ZSH_PROFILE_DEBUG is set
[[ -n "${ZSH_PROFILE_DEBUG}" ]] && setopt XTRACE

# Track loading time if ZSH_PROFILE_BENCHMARK is set
typeset -g _zsh_profile_start_time
if [[ -n "${ZSH_PROFILE_BENCHMARK}" ]]; then
	zmodload zsh/datetime
	_zsh_profile_start_time=$EPOCHREALTIME
fi

# Helper function for safe sourcing with error handling
_zsh_source_file() {
	local zsh_file=$1
	local stage=${2:-unknown}

	if [[ ! -f "$zsh_file" ]]; then
		print -u2 "Warning: File not found: $zsh_file"
		return 1
	elif [[ ! -r "$zsh_file" ]]; then
		print -u2 "Warning: File not readable: $zsh_file"
		return 1
	fi

	if [[ -n "${ZSH_PROFILE_BENCHMARK}" ]]; then
		local t_start=$EPOCHREALTIME
		source "$zsh_file"
		local t_end=$EPOCHREALTIME
		local elapsed=$(( t_end - t_start ))
		print -u2 "[$stage] ${zsh_file:t} took ${elapsed}s"
	else
		source "$zsh_file"
	fi
}

# Helper function for sourcing directories
_zsh_source_dir() {
	local target_dir=$1
	local stage=${2:-unknown}
	local pattern=${3:-"*.zsh"}

	if [[ ! -d "$target_dir" ]]; then
		[[ -n "${ZSH_PROFILE_DEBUG}" ]] && print -u2 "Debug: Directory not found: $target_dir"
		return 0
	fi

	# Use glob qualifiers: N (null_glob), . (regular LIST_files), o (order by name)
	local LIST_files=("${target_dir}/${pattern}"(N.on))

	if (( ${#LIST_files} == 0 )); then
		[[ -n "${ZSH_PROFILE_DEBUG}" ]] && print -u2 "Debug: No LIST_files matching ${pattern} in ${target_dir}"
		return 0
	fi

	local zsh_file
	for zsh_file in ${LIST_files}; do
		_zsh_source_file "$zsh_file" "$stage"
	done
}

# ============================================================================
# Stage 1: Load core library functions
# These are fundamental utilities needed everywhere (command-has, print_fn, etc.)
# ============================================================================
_zsh_source_dir "${ZDOTDIR}/lib/core" "lib/core"

# ============================================================================
# Stage 2: Load environment configuration
# Environment variables, XDG paths, etc.
# Files are loaded in numeric order (00-, 10-, 20-, ...)
# ============================================================================
_zsh_source_dir "${ZDOTDIR}/env" "env"

# Benchmark output for .zshenv stage
if [[ -n "${ZSH_PROFILE_BENCHMARK}" ]]; then
	local t_end=$EPOCHREALTIME
	local total=$(( t_end - _zsh_profile_start_time ))
	print -u2 "[TOTAL] .zshenv stage took ${total}s"
fi

# vim: ft=zsh ts=4 sw=4 et
