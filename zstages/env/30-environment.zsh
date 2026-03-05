##############################################################################
### Custom packages locations
###
### Any variable here should be set once at boot.
### If a new one is added, a reboot is in order.
###
### Variables that point to config files should be set here.
##############################################################################

# Source environment files from extensions
for zshfile in ${ZDOTDIR}/extensions/*/*.env.zsh(N); do
    source "$zshfile"
done
unset zshfile

# FIXME: Add pacman hook to reload the environment on package installation
