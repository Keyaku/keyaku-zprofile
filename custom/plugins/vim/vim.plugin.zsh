(( ${+commands[vim]} )) || return

# Create vim config path and set user vimrc
[[ -d "${XDG_CONFIG_HOME}/vim" ]] || mkdir -p "${XDG_CONFIG_HOME}/vim"
export MYVIMRC="${XDG_CONFIG_HOME}/vim/vimrc"

# Copy the whole vimrc file. Any user plugin should be loaded in a 'plugins' file, or additional configuration in 'myvimrc'
if ! fastcmp "$ZDOTDIR/conf/vim/vimrc" "$MYVIMRC"; then
	mv "$MYVIMRC"{,.old}
	cp "$ZDOTDIR/conf/vim/vimrc" "$MYVIMRC"
fi
