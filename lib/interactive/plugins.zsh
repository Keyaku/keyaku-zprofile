# ============================================================================
# Setup plugins environment
#
# Declare necessary global variables to be used at each stage of ZSH, so that
# they load plugins respectively.
#
# NOTE: This is NOT the place to store which plugins to load.
# ============================================================================

# typeset -aU _plugins_path=()
# typeset -aU plugins_env=() # loaded at .zshenv
# typeset -aU plugins_profile=() # loaded at .zprofile
typeset -aU plugins=() # loaded at .zshrc (by OMZ or otherwise)
