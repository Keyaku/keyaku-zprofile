##############################################################################
# fpath and plugin discovery (with or without Oh-My-Zsh)
##############################################################################
# Runs before compinit (OMZ's in 25-omz-load.zsh or ours in 26-compinit.zsh), so
# every completion directory must be in place by now. The plugin files found
# here are handed to the loader in 27-plugins-load.zsh via ZPROFILE_PLUGIN_FILES.

if (( ${ZSH_PROFILE_BENCHMARK} )); then
	zmodload zsh/datetime
	local -F _tfpath0=$EPOCHREALTIME
fi

# OMZ's plugin dir is only searched when OMZ is loaded (20-omz-setup.zsh sets $ZSH)
local -a plugins_rootpaths=("$ZSH_CUSTOM")
[[ -n "$ZSH" ]] && plugins_rootpaths+=("$ZSH")

local plugin plugin_path
local -a plugin_dirs fpaths_found
typeset -ga ZPROFILE_PLUGIN_FILES=()

# Collect plugins and fpaths to use
for plugin ($plugins); do
	# Find directory with either file first, then pick the first result.
	plugin_dirs=(${^plugins_rootpaths}/plugins/$plugin/{_$plugin,$plugin.plugin.zsh}(.N:h))
	plugin_path="${plugin_dirs[1]}"
	if [[ -n "$plugin_path" ]]; then
		# Use path for previously found completion files
		fpaths_found+=("$plugin_path"/_$plugin(.N:h))
		ZPROFILE_PLUGIN_FILES+=("$plugin_path"/$plugin.plugin.zsh(.N))
	else
		print_fn -e "plugin $plugin not found"
	fi
done
unset plugin

# Completions written at runtime (e.g. by extensions/docker) live in the cache
[[ -d "$ZSH_CACHE_DIR/completions" ]] || mkdir -p "$ZSH_CACHE_DIR/completions"

# Update fpath
fpath=(
	$ZDOTDIR/completions
	${fpaths_found}
	$ZSH_CUSTOM/{functions,completions}(/N)
	$ZSH_CACHE_DIR/completions
	$fpath
)

if (( ${ZSH_PROFILE_BENCHMARK} )); then
	print "fpath prep: $(( (EPOCHREALTIME-_tfpath0) ))s"
fi
[[ -n "${ZSH_PROFILE_DEBUG}" ]] && printf '>>> %s: %s\n' "fpaths_found" "${fpaths_found}" plugins_found "${ZPROFILE_PLUGIN_FILES}"
