# ============================================================================
# First-time initialization check
# ============================================================================
if (( $UID >= 1000 )) && [[ ! -f "$ZDOTDIR/conf/.first_init" ]] || (( 1 != $(cat "$ZDOTDIR/conf/.first_init") )); then
	print -u2 "Warning: The ZSH profile was not initialized. Run the following command to ensure everything works as expected:"
	printf "\t%s\n" "zsh "$ZDOTDIR"/conf/first_init.zsh"
fi

# ============================================================================
# Initialize submodules if ohmyzsh is not present or empty
# ============================================================================

[[ "${ZPROFILE_MODULES}" ]] || ZPROFILE_MODULES=($(git -C "$ZDOTDIR" config --file .gitmodules --get-regexp path | awk '{ print $2 }'))
if [[ "$(echo "$ZDOTDIR"/$^ZPROFILE_MODULES/(N^F))" ]]; then
	# Initialize submodules
	zupdate --submodules
fi

# ============================================================================
# Setup plugins environment
# ============================================================================
# Declare necessary global variables to be used at each stage of ZSH, so that
# they load plugins respectively.
# NOTE: This is NOT the place to store which plugins to load.

# typeset -aU _plugins_path=()
# typeset -aU plugins_env=() # loaded at .zshenv
# typeset -aU plugins_profile=() # loaded at .zprofile
typeset -aU plugins=() # loaded at .zshrc (by OMZ or otherwise)
