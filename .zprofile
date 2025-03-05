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
	# Switch to main branch and pull latest changes
	git -C "$ZDOTDIR" submodule foreach 'defb=$(git remote show origin | sed -n "/HEAD branch/s/.*: //p"); git checkout -q $defb && git pull -q origin $defb'
fi

# Load function that loads all custom functions
# FIXME: In theory, this should not be present in .zprofile. Modify .zprofile to avoid this.
autoload -Uz "${ZSH_CUSTOM:-$ZDOTDIR/custom}"/functions/{.,^.}**/load_zfunc(N) && load_zfunc

### Check for zprofile git repo changes
# FIXME: This adds delay to shell startup. Find solution to run this in background, or with timestamp check.
# zprofile-update -q

### Load login environment variables
# FIXME: Currently loads all files; implement loading login ones
zsource -a

### Local bin
[[ -d "$HOME/.local/bin" ]] || mkdir -p "$HOME/.local/bin"
addpath -p "$HOME/.local/bin"
