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

# Add all non-empty subdirectories of .zfunc to fpath
if ! [[ " $fpath " =~ "${ZDOTDIR}/.zfunc" ]]; then
	fpath=("${ZDOTDIR}"/.zfunc/**/*~*/(CVS)#(/N) ${fpath})
fi
function load_functions {
	## Setup func opts
	local f_help f_reload
	zparseopts -D -F -K -- \
		{r,-reload}=f_reload \
		|| return 1

	if [[ "$f_reload" ]]; then
		# Reload all functions
		unfunction "${ZDOTDIR}"/.zfunc/**/*(-.DN:t^/)
	fi

	# Load core custom functions (directories that begin with .)
	autoload -Uz "${ZDOTDIR}"/.zfunc/.**/*(-.D)
	# Load ALL other custom functions
	autoload -Uz "${ZDOTDIR}"/.zfunc/**/*(-.N^/)
}
load_functions

### Check for zprofile git repo changes
zprofile-update -q

### Load login environment via env_update (and load it in case it isn't)
if ! command -v env_update &>/dev/null; then
	grep -rEl "\s*(function\s+)(env_update)(\s*\(\))?" "${ZDOTDIR}/profile.d" | while IFS= read; do
		source "$REPLY"
	done
fi

env_update


##############################################################################
### Custom packages locations
###
### These can be reloaded without requiring a reboot.
##############################################################################

### Android development
if command-has adb; then
	if [[ -d "${ANDROID_HOME}/sdk/platform-tools" ]]; then
		addpath 1 "${ANDROID_HOME}/sdk/platform-tools"
	fi
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
