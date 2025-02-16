#######################################
### Microsoft
#######################################

if [[ -o login ]]; then

### .NET
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


fi
