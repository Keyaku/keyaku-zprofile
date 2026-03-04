(( ${+commands[vim]} )) || return

# Copy the whole vimrc file. Any user plugin should be loaded in a 'plugins' file, or additional configuration in 'myvimrc'
if [[ ! -f "$MYVIMRC" ]]; then
	mv "$MYVIMRC"{,.old}
	cp "$ZDOTDIR/conf/vim/vimrc" "$MYVIMRC"
fi
