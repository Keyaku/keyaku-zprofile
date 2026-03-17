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

# Clean up fpath duplicates introduced by omz
fpath=(${(u)fpath})
