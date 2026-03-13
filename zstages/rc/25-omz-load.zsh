##############################################################################
# Oh-My-ZSH load file
##############################################################################

# Check for Oh-My-ZSH; stop processing if not found
[[ -n "$ZSH" && -f "${ZSH}/oh-my-zsh.sh" ]] || return

# Load ohmyzsh
_zsh_source_file "$ZSH"/oh-my-zsh.sh

# Clean up mess done by ohmyzsh
fpath=(${(u)fpath})
