##############################################################################
### Custom packages locations
###
### Any variable here should be set once at boot.
### If a new one is added, a reboot is in order.
###
### Variables that point to config files should be set here.
##############################################################################

# Source environment files from extensions
_zsh_source_dir ${ZDOTDIR}/extensions "extensions/*.env.zsh" '*/*.env.zsh'
