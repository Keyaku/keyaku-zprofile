if (( ! ${+DOTNET_ROOT} )); then
	# Use Homebrew's .NET installation
	if (( ${+HOMEBREW_PREFIX} )) && [[ -d "$HOMEBREW_CELLAR/dotnet" ]]; then
		export DOTNET_ROOT="${HOMEBREW_PREFIX}/opt/dotnet/libexec"
	# Use user installation
	elif [[ "${XDG_DATA_HOME}/dotnet" ]]; then
		export DOTNET_ROOT="${XDG_DATA_HOME}/dotnet"
	fi
fi

(( ${+DOTNET_ROOT} )) || return

export DOTNET_INSTALL_DIR="${DOTNET_ROOT}"
[[ -d "$DOTNET_INSTALL_DIR/.dotnet/tools" ]] && addpath "$DOTNET_INSTALL_DIR/.dotnet/tools"
export DOTNET_CLI_HOME="${DOTNET_ROOT}"
export DOTNET_CLI_TELEMETRY_OPTOUT=true
export NUGET_PACKAGES="${XDG_CACHE_HOME}/NuGetPackages"

(( ${+commands[dotnet]} )) || return

# The portion below is copied from (MIT License):
# https://raw.githubusercontent.com/dotnet/sdk/main/scripts/register-completions.zsh

#compdef dotnet
_dotnet_completion() {
	local -a completions=("${(@f)$(dotnet complete "${words}")}")
	compadd -a completions
	_files
}

compdef _dotnet_completion dotnet
