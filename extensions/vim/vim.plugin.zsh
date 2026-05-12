(( ${+commands[vim]} )) || return

# Copy the whole vimrc file. Any user plugin should be loaded in a 'plugins' file, or additional configuration in 'myvimrc'
if [[ -n "$MYVIMRC" && ! -f "$MYVIMRC" ]]; then
	[[ -d "${MYVIMRC:h}" ]] || mkdir -p "${MYVIMRC:h}"
	cp "$ZDOTDIR/conf/home/vim/vimrc" "$MYVIMRC"
fi

# Alias to open vim with encoding information
alias vimenc='vim -c '\''let $enc = &fileencoding | execute "!echo Encoding:  $enc" | q'\'''
