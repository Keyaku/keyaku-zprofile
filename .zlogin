#####################################################################
#                            .zlogin
#
# File loaded 4th && if [[ -o login ]]
#
# Used for executing user's commands at ending of initial progress,
# will be read when starting as a login shell.
# Typically used to autostart command line utilities.
# Should not be used to autostart graphical sessions,
# as at this point the session might contain configuration
# meant only for an interactive shell.
#####################################################################

### Source login stage
_zsh_source_dir "${ZDOTDIR}/zstages/login" "login"
