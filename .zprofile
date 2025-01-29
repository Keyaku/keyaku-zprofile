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
zprofile-reload


##############################################################################
### Custom packages locations
###
### These can be reloaded without requiring a reboot.
##############################################################################

### Android development
if [[ -d "${ANDROID_HOME}/sdk/platform-tools" ]]; then
	addpath 1 "${ANDROID_HOME}/sdk/platform-tools"
fi
command-has termux-adb && alias termux-adb="HOME=$ANDROID_HOME termux-adb"


### Microsoft
export DOTNET_CLI_TELEMETRY_OPTOUT=true
if (( 1000 <= $UID )) && command-has brew && [[ -d "$HOMEBREW_CELLAR/dotnet" ]]; then
	export DOTNET_ROOT="${HOMEBREW_PREFIX}/opt/dotnet/libexec"
else
	export DOTNET_ROOT="${XDG_DATA_HOME}/dotnet"
fi
export DOTNET_INSTALL_DIR="${DOTNET_ROOT}"
export DOTNET_CLI_HOME="${DOTNET_ROOT}"
export NUGET_PACKAGES="${XDG_CACHE_HOME}/NuGetPackages"
[[ -d "$DOTNET_INSTALL_DIR/.dotnet/tools" ]] && addpath "$DOTNET_INSTALL_DIR/.dotnet/tools"


### Python
if [[ -d "${XDG_DATA_HOME}"/pyvenv && -f "${XDG_DATA_HOME}"/pyvenv/pyvenv.cfg ]] && ! array_has path "${XDG_DATA_HOME}"/pyvenv/bin; then
	source "${XDG_DATA_HOME}"/pyvenv/bin/activate
fi

### Sonarlint
export SONARLINT_USER_HOME="$XDG_DATA_HOME/sonarlint"

### Subversion (SVN)
if command-has svn && ! alias svn &>/dev/null; then
	alias svn='svn --config-dir ${XDG_CONFIG_HOME}/subversion'
fi

### Local bin
addpath 1 "$HOME/.local/bin"
