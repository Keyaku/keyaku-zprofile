#######################################
### Microsoft
#######################################

if [[ -o login ]]; then

### .NET
# Use Homebrew's .NET installation
if (( ${+HOMEBREW_PREFIX} )) && [[ -d "$HOMEBREW_CELLAR/dotnet" ]]; then
	export DOTNET_ROOT="${HOMEBREW_PREFIX}/opt/dotnet/libexec"
# Use user installation
elif [[ "${XDG_DATA_HOME}/dotnet" ]]; then
	export DOTNET_ROOT="${XDG_DATA_HOME}/dotnet"
elif [[ -z "$DOTNET_ROOT" ]] && is_sourced; then
	return 1
fi

export DOTNET_INSTALL_DIR="${DOTNET_ROOT}"
[[ -d "$DOTNET_INSTALL_DIR/.dotnet/tools" ]] && addpath "$DOTNET_INSTALL_DIR/.dotnet/tools"
export DOTNET_CLI_HOME="${DOTNET_ROOT}"
export DOTNET_CLI_TELEMETRY_OPTOUT=true
export NUGET_PACKAGES="${XDG_CACHE_HOME}/NuGetPackages"

fi
