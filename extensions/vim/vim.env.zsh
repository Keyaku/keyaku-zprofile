(( ${+commands[vim]} )) || return

# Create vim config path and set user vimrc
[[ -d "${XDG_CONFIG_HOME}/vim" ]] || mkdir -p "${XDG_CONFIG_HOME}/vim"
export MYVIMRC="${XDG_CONFIG_HOME}/vim/vimrc"
