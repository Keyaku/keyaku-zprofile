#####################################################################
#                            .zshrc
#
# File loaded 3rd && if [[ -o interactive ]]
#
# Used for setting user's interactive shell configuration
# and executing commands, will be read when starting
# as an *interactive shell*.
#####################################################################

# Track loading time if ZSH_PROFILE_BENCHMARK is set
typeset -g _zsh_profile_start_time
if [[ -n "${ZSH_PROFILE_BENCHMARK}" ]]; then
	zmodload zsh/datetime
	_zsh_profile_start_time=$EPOCHREALTIME
fi

# Required setopts for this setup to work
setopt extendedglob
setopt re_match_pcre

# Load all custom functions
export ZSH_CUSTOM="$ZDOTDIR/custom"
autoload -Uz "$ZSH_CUSTOM"/functions/{,.}**/zsource(.N) && zsource -ef

# Source interactive library functions
_zsh_source_dir "${ZDOTDIR}/lib/interactive" "lib/interactive"

# Source interactive stage
_zsh_source_dir "${ZDOTDIR}/zstages/rc" "rc"

# Preferred editor
export EDITOR='vim'

# powerlevel10k. To customize prompt, run `p10k configure` or edit $ZDOTDIR/.p10k.zsh.
[[ "$ZSH_THEME" == "powerlevel10k" && -f "$ZDOTDIR"/.p10k.zsh ]] && source "$ZDOTDIR"/.p10k.zsh

# Benchmark output for this stage
if [[ -n "${ZSH_PROFILE_BENCHMARK}" ]]; then
	local t_end=$EPOCHREALTIME
	local total=$(( t_end - _zsh_profile_start_time ))
	print -u2 "[TOTAL] $(is_sourced_by) stage took ${total}s"
fi
