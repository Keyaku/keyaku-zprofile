#####################################################################
#                            .zprofile
#
# File loaded 2nd && if [[ -o login ]]
#
# Used for executing user's commands at start,
# will be read when starting as a *login shell*.
# Typically used to autostart graphical sessions
# and to set session-wide environment variables.
#####################################################################

### Source path/session functions
_zsh_source_dir "${ZDOTDIR}/lib/login" "lib/login"

### Source profile stage
_zsh_source_dir "${ZDOTDIR}/profile" "profile"
