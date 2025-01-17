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

### Load login environment via env_update (and load it in case it isn't)
if ! command -v env_update &>/dev/null; then
	grep -rEl "\s*(function\s+)(get_funcname|env_update|command_has)(\s*\(\))?" "${ZDOTDIR}/profile.d" | while IFS= read; do
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
if command_has adb; then
	if [[ -d "${ANDROID_HOME}/sdk" ]]; then
		export ANDROID_SDK_HOME="${ANDROID_HOME}/sdk"
		addpath 1 "${ANDROID_SDK_HOME}/platform-tools"
	fi
fi
command_has termux-adb && alias termux-adb="HOME=$ANDROID_HOME termux-adb"


### Microsoft
export DOTNET_CLI_TELEMETRY_OPTOUT=true
if (( 1000 <= $UID )) && command_has brew && [[ -d "$HOMEBREW_CELLAR/dotnet" ]]; then
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
if command_has svn && ! alias svn &>/dev/null; then
	alias svn='svn --config-dir ${XDG_CONFIG_HOME}/subversion'
fi

### Local bin
addpath 1 "$HOME/.local/bin"
