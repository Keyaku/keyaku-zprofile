##############################################################################
### Custom packages locations
###
### Any variable here should be set once at boot.
### If a new one is added, a reboot is in order.
###
### Variables that point to config files should be set here.
##############################################################################

# Add user's local bin directory to path
[[ -d "$HOME/.local/bin" ]] || mkdir -p "$HOME/.local/bin"
haspath "$HOME/.local/bin" || addpath 1 "$HOME/.local/bin"

# Source environment files from extensions
_zsh_source_dir ${ZDOTDIR}/extensions "extensions/*.env.zsh" '*/*.env.zsh'
