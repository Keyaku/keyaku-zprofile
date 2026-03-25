##############################################################################
# Oh-My-ZSH load file
##############################################################################

# Check for Oh-My-ZSH; stop processing if not found
[[ -n "$ZSH" && -f "${ZSH}/oh-my-zsh.sh" ]] || return

if (( ${ZSH_PROFILE_BENCHMARK} )); then
	zmodload zsh/datetime
	local -F _tfpath0 _tfpath1 _t0 _t1 _t2 _t3 _tsources _tploader0 _tploader1
	_tfpath0=$EPOCHREALTIME
fi

# ============================================================================
# Prepare fpath for plugins before omz loads
# ============================================================================
local -a plugins_rootpaths=("$ZSH_CUSTOM" "$ZSH")

local plugin plugin_path
local -a plugin_dirs fpaths_found plugins_found

# Collect plugins and fpaths to use
for plugin ($plugins); do
	# Find directory with either file first, then pick the first result.
	plugin_dirs=(${^plugins_rootpaths}/plugins/$plugin/{_$plugin,$plugin.plugin.zsh}(.N:h))
	plugin_path="${plugin_dirs[1]}"
	if [[ -n "$plugin_path" ]]; then
		# Use path for previously found completion files
		fpaths_found+=("$plugin_path"/_$plugin(.N:h))
		plugins_found+=("$plugin_path"/$plugin.plugin.zsh(.N))
	else
		print_fn -e "plugin $plugin not found"
	fi
done

# Update fpath
fpath=(${fpaths_found} $fpath)

if (( ${ZSH_PROFILE_BENCHMARK} )); then
	print "fpath prep: $(( (EPOCHREALTIME-_tfpath0) ))s"
	# printf '>>> %s: %s\n' "fpaths_found" "${fpaths_found}" plugins_found "${plugins_found}"
fi

# ============================================================================
# Load ohmyzsh
# ============================================================================
# Save plugins array and clear it so omz skips plugin loading
local -a _plugins=($plugins)
plugins=()

_zsh_source_file "$ZSH"/oh-my-zsh.sh

# ============================================================================
# Restore and load plugins with our loader
# ============================================================================
plugins=($_plugins)

local -A aliases_pre
local plugin_file disable_aliases

if (( ${ZSH_PROFILE_BENCHMARK} )); then
	_tploader0=$EPOCHREALTIME
fi

for plugin_file in ${plugins_found}; do
	plugin="${plugin_file:h:t}"

	# (( ${ZSH_PROFILE_BENCHMARK} )) && _t0=$EPOCHREALTIME
	disable_aliases=0
	zstyle -T ":omz:plugins:$plugin" aliases || disable_aliases=1
	# (( ${ZSH_PROFILE_BENCHMARK} )) && _t1=$EPOCHREALTIME

	if (( disable_aliases )); then
		aliases_pre=("${(@kv)aliases}")

		(( ${ZSH_PROFILE_BENCHMARK} )) && _t2=$EPOCHREALTIME
		_zsh_source_file "$plugin_file"
		(( ${ZSH_PROFILE_BENCHMARK} )) && _t3=$EPOCHREALTIME

		aliases=("${(@kv)aliases_pre}")
	else
		(( ${ZSH_PROFILE_BENCHMARK} )) && _t2=$EPOCHREALTIME
		_zsh_source_file "$plugin_file"
		(( ${ZSH_PROFILE_BENCHMARK} )) && _t3=$EPOCHREALTIME
	fi
	(( ${ZSH_PROFILE_BENCHMARK} )) && _tsources=$((_tsources + (_t3-_t2)))
done

if (( ${ZSH_PROFILE_BENCHMARK} )); then
	_tploader1=$EPOCHREALTIME
	print "plugin loader: $((_tploader1-_tploader0 - _tsources))s"
	# print "plugin sources: $((_tsources))s"
	# print "plugin total: $((_tploader1-_tploader0))s"
fi

# Clear fpath duplicates added by omz. Comment this line in case fpath is bloated
fpath=(${(u)fpath})
