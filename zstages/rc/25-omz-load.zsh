##############################################################################
# Oh-My-ZSH load file
##############################################################################

# Check for Oh-My-ZSH; stop processing if not found
[[ -n "$ZSH" && -f "${ZSH}/oh-my-zsh.sh" ]] || return

# Save plugins array and clear it so omz skips plugin loading; our own loader
# (27-plugins-load.zsh) loads them after compinit.
local -a _plugins=($plugins)
plugins=()

_zsh_source_file "$ZSH"/oh-my-zsh.sh

plugins=($_plugins)
