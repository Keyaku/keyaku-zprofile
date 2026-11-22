##############################################################################
# zsh-syntax-highlighting
##############################################################################
# It wraps every ZLE widget defined before it, so it's sourced last in the rc
# stage. Uses the vendored submodule unless it's disabled
# (`zsubmod --off zsh-syntax-highlighting`) or not checked out, then falls back
# to a copy installed by the system's package manager.

() {
	local zsh_hl="$ZDOTDIR"/vendor/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
	if ! _zsubmodule_enabled zsh-syntax-highlighting || [[ ! -f "$zsh_hl" ]]; then
		zsh_hl=$(_zsh_highlight_system_path) || return 0
	fi
	_zsh_source_file "$zsh_hl"
}
