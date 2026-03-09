(( ${+commands[dotnet]} )) || return

# Set DOTNET_ROOT if it's not already set
if (( ! ${+DOTNET_ROOT} )); then
	# Use Homebrew's .NET installation
	if (( ${+HOMEBREW_PREFIX} )) && [[ -d "$HOMEBREW_CELLAR/dotnet" ]]; then
		export DOTNET_ROOT="${HOMEBREW_PREFIX}/opt/dotnet/libexec"
	# Use user installation
	elif [[ -d "${XDG_DATA_HOME}/dotnet" ]]; then
		export DOTNET_ROOT="${XDG_DATA_HOME}/dotnet"
	fi
fi

(( ${+DOTNET_ROOT} )) || return

[[ -d "$HOME"/.dotnet ]] && xdg-migrate "$HOME"/.dotnet "$DOTNET_ROOT"

export DOTNET_INSTALL_DIR="${DOTNET_ROOT}"
[[ -d "$DOTNET_INSTALL_DIR/.dotnet/tools" ]] && addpath "$DOTNET_INSTALL_DIR/.dotnet/tools"
export DOTNET_CLI_HOME="${DOTNET_ROOT}"
export DOTNET_CLI_TELEMETRY_OPTOUT=true
export NUGET_PACKAGES="${XDG_CACHE_HOME}/NuGetPackages"
