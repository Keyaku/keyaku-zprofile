##############################################################################
# Oh-My-ZSH load file
##############################################################################

# Check for Oh-My-ZSH; stop processing if not found
[[ -n "$ZSH" && -f "${ZSH}/oh-my-zsh.sh" ]] || return

# ============================================================================
# Prepare fpath for plugins before omz loads
# ============================================================================
local -a plugins_rootpaths=("$ZSH_CUSTOM" "$ZSH")
typeset -ga plugins_found fpaths_found

local plugin
for plugin ($plugins); do
	local -a fpath_results=(${^plugins_rootpaths}/plugins/$plugin/_*(.N:h))
	fpaths_found+=(${fpath_results[1]})
	local -a plugin_results=(${^fpath_results[1]:-${^plugins_rootpaths}/plugins/$plugin}/$plugin.plugin.zsh(.N))
	plugins_found+=(${plugin_results[1]})
done

# Update fpath
fpath=(${fpaths_found} $fpath)

# FIXME: these are not correct solutions. Right now, if a plugin exists in both
# custom/ and ohmyzsh/, both paths will be added to fpath, and both will be
# sourced by the plugin loader.
# The logic is supposed to pick the first of plugins_rootpaths found.

# # Update fpath with directories containing a completion (_*) file
# fpath_results=(${^plugins_rootpaths}/plugins/${^plugins}/_*(.N:h))
# fpath=(${fpath_results} $fpath)

# # Gather all directories with a .plugin.zsh
# plugins_found=(${^fpaths_found:-${^plugins_rootpaths}/plugins}/${fpaths_found:t}.plugin.zsh(.N))

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
