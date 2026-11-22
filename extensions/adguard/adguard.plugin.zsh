[ -s "/opt/adguard-cli/bash-completion.sh" ] || return

# Link the bash completion file where zstages/rc/30-completion.zsh loads them
() {
	local -r comp_dir="${XDG_DATA_HOME:-$HOME/.local/share}"/bash-completion/completions
	[[ -L "$comp_dir/adguard-cli" || -L "$comp_dir/bash-completion.sh" ]] && return  # (older installs used the latter name)
	[[ -d "$comp_dir" ]] || mkdir -p "$comp_dir"
	ln -sfn /opt/adguard-cli/bash-completion.sh "$comp_dir/adguard-cli" && \
		print_fn -i "Linked AdGuard CLI's bash completion into $comp_dir"
}
