##############################################################################
# Oh-My-ZSH load file
##############################################################################

# Check for Oh-My-ZSH; stop processing if not found
[[ -n "$ZSH" && -f "${ZSH}/oh-my-zsh.sh" ]] || return

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

for plugin_file in ${plugins_found}; do
	plugin="${plugin_file:h:t}"

	disable_aliases=0
	zstyle -T ":omz:plugins:$plugin" aliases || disable_aliases=1

	if (( disable_aliases )); then
		aliases_pre=("${(@kv)aliases}")

		_zsh_source_file "$plugin_file"

		aliases=("${(@kv)aliases_pre}")
	else
		_zsh_source_file "$plugin_file"
	fi
done

# Clear fpath duplicates added by omz. Comment this line in case fpath is bloated
fpath=(${(u)fpath})
