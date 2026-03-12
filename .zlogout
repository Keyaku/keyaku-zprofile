##############################################################################
#                            .zlogout
#
# File loaded LAST && if [[ -o login ]]
#
# Used for executing commands when a *login shell exits*.
##############################################################################

# No benchmark required because we are leaving the shell.

# ============================================================================
# Stage 1: Load zlogout stage files
# ============================================================================

_zsh_source_dir "${ZDOTDIR}/zstages/logout" "logout"
