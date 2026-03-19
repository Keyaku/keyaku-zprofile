##############################################################################
# Oh-My-ZSH load file
##############################################################################

# Check for Oh-My-ZSH; stop processing if not found
[[ -n "$ZSH" && -f "${ZSH}/oh-my-zsh.sh" ]] || return

# ============================================================================
# Prepare fpath for plugins before omz loads
# ============================================================================
local -A plugin_map=()

local -a plugin_dirs=("$ZSH_CUSTOM" "$ZSH")
local -a plugin_results
local plugin plugin_found

for plugin ($plugins); do
	plugin_results=(${^plugin_dirs}/plugins/$plugin/{_*,$plugin.plugin.zsh}(.N))
	if (( ! ${#plugin_results} )); then
		print_fn -w "plugin '$plugin' not found"
		continue
	fi
	for plugin_found ($plugin_results); do
		if [[ "${plugin_found:e}" == "zsh" ]]; then
			plugin_map[$plugin]="${plugin_found:h}"
		elif [[ "${plugin_found:t}" == "_$plugin" ]]; then
			fpath=("${plugin_found:h}" $fpath)
		fi
	done
done

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

local -A aliases_pre galiases_pre
local plugin_file plugin_dir disable_aliases
for plugin plugin_dir in ${(kv)plugin_map}; do
	plugin_file="${plugin_dir}/$plugin.plugin.zsh"

	disable_aliases=0
	zstyle -T ":omz:plugins:$plugin" aliases || disable_aliases=1

	if (( disable_aliases )); then
		aliases_pre=("${(@kv)aliases}")
		galiases_pre=("${(@kv)galiases}")

		_zsh_source_file "$plugin_file"

		aliases=("${(@kv)aliases_pre}")
		galiases=("${(@kv)galiases_pre}")
	else
		_zsh_source_file "$plugin_file"
	fi
done

# Clear fpath duplicates added by omz. Stays commented just in case.
# fpath=(${(u)fpath})
