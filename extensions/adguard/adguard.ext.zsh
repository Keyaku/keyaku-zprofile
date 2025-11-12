[ -s "/opt/adguard-cli/bash-completion.sh" ] || return

if [[ -f "/opt/adguard-cli/bash-completion.sh" ]]; then
	# Move or link bash completion file to home for bash completions
	[[ -d "${$XDG_DATA_HOME:-$HOME/.local/share}"/bash-completion/completions ]] || mkdir -p "${$XDG_DATA_HOME:-$HOME/.local/share}"/bash-completion/completions
	ln -s "/opt/adguard-cli/bash-completion.sh" "${$XDG_DATA_HOME:-$HOME/.local/share}"/bash-completion/completions/.
fi
