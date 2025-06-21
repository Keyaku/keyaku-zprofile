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

# Initialize submodules if ohmyzsh is not present or empty
[[ "${ZPROFILE_MODULES}" ]] || ZPROFILE_MODULES=($(git -C "$ZDOTDIR" config --file .gitmodules --get-regexp path | awk '{ print $2 }'))
if [[ "$(echo "$ZDOTDIR"/$^ZPROFILE_MODULES/(N^F))" ]]; then
	echo "Initializing submodules..."
	# Initialize submodules
	git -C "$ZDOTDIR" submodule -q update --init --remote --recursive
fi

# Load function that loads all custom functions
# FIXME: In theory, this should not be present in .zprofile. Modify .zprofile to avoid this.
setopt extendedglob
autoload -Uz "${ZSH_CUSTOM:-$ZDOTDIR/custom}"/functions/{.,^.}**/zsource(N)
zsource -a

### Local bin
[[ -d "$HOME/.local/bin" ]] || mkdir -p "$HOME/.local/bin"
haspath "$HOME/.local/bin" || addpath -p "$HOME/.local/bin"
