#####################################################################
#                            .zlogout
#
# File loaded LAST && if [[ -o login ]]
#
# Used for executing commands when a *login shell exits*.
#####################################################################

### Source logout stage
_zsh_source_dir "${ZDOTDIR}/zstages/logout" "logout"
