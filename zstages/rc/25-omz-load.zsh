##############################################################################
# Oh-My-ZSH load file
##############################################################################

# Check for Oh-My-ZSH; stop processing if not found
[[ -n "$ZSH" && -f "${ZSH}/oh-my-zsh.sh" ]] || return

ZSH_PROFILE_BENCHMARK=1
zmodload zsh/datetime
local t_zsh_start t_total=$EPOCHREALTIME
typeset -i USE_OMZ_PLUGIN=0

# ============================================================================
# Prepare fpath for plugins before omz loads
# ============================================================================
if (( ! ${USE_OMZ_PLUGIN} )); then
	if (( ${ZSH_PROFILE_BENCHMARK} )); then
		t_zsh_start=$EPOCHREALTIME
	fi

	local -A plugin_map=()

	local -a plugin_dirs=("$ZSH_CUSTOM" "$ZSH")
	local -a found_files
	local plugin found

	for plugin ($plugins); do
		found_files=(${^plugin_dirs}/plugins/$plugin/{$plugin.plugin.zsh,_$plugin}(.N))
		if (( ! ${#found_files} )); then
			print_fn -w "plugin '$plugin' not found"
			continue
		fi
		for found ($found_files); do
			if [[ "${found:e}" == "zsh" ]]; then
				plugin_map[$plugin]="${found:h}"
			elif [[ "${found:t}" == "_$plugin" ]]; then
				fpath=("${found:h}" $fpath)
			fi
		done
	done

	if (( ${ZSH_PROFILE_BENCHMARK} )); then
		print -u2 "[${0:t}] plugins in fpath took $(( $EPOCHREALTIME - t_zsh_start ))s"
		t_zsh_start=$EPOCHREALTIME
	fi
fi


# ============================================================================
# Load ohmyzsh
# ============================================================================
# Save plugins array and clear it so omz skips plugin loading
if (( ! ${USE_OMZ_PLUGIN} )); then
	local -a _plugins=($plugins)
	plugins=()
fi

_zsh_source_file "$ZSH"/oh-my-zsh.sh

# ============================================================================
# Restore and load plugins with our loader
# ============================================================================
if (( ! ${USE_OMZ_PLUGIN} )); then
	if (( ${ZSH_PROFILE_BENCHMARK} )); then
		t_zsh_start=$EPOCHREALTIME
	fi

	plugins=($_plugins)
	local plugin_file plugin_dir disable_aliases
	for plugin plugin_dir in ${(kv)plugin_map}; do
		plugin_file="${plugin_dir}/$plugin.plugin.zsh"

		disable_aliases=0
		zstyle -T ":omz:plugins:$plugin" aliases || disable_aliases=1

		if (( disable_aliases )); then
			local -A aliases_pre=("${(@kv)aliases}")
			source "$plugin_file"
			aliases=("${(@kv)aliases_pre}")
		else
			source "$plugin_file"
		fi
	done

	if (( ${ZSH_PROFILE_BENCHMARK} )); then
		print -u2 "[${0:t}] plugin loader took $(( $EPOCHREALTIME - t_zsh_start ))s"
		t_zsh_start=$EPOCHREALTIME
	fi
fi

# Clean up fpath duplicates introduced by omz
fpath=(${(u)fpath})

if (( ${ZSH_PROFILE_BENCHMARK} )); then
	print -u2 "[TOTAL] ${0:t} took $(( $EPOCHREALTIME - t_total ))s"
fi
unset ZSH_PROFILE_BENCHMARK
