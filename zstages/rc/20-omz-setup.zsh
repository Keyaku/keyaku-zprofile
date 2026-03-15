##############################################################################
# Oh-My-ZSH pre-load configuration file
##############################################################################

# Check for Oh-My-ZSH; stop processing if not found
[[ -f "$ZDOTDIR/vendor/ohmyzsh/oh-my-zsh.sh" ]] || return

# Path to oh-my-zsh installation.
export ZSH="$ZDOTDIR/vendor/ohmyzsh"

# Prepare ohmyzsh specifically for this configuration
zstyle ':zprofile:submodules:ohmyzsh' loaded true
zstyle ':omz:update' mode disabled  # disable automatic updates
