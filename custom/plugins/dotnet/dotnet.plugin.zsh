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
