### ZSH profile
export ZSH_CACHE_HOME="${XDG_CACHE_HOME}/zsh"
[[ -d "$ZSH_CACHE_HOME" ]] || mkdir -p "$ZSH_CACHE_HOME"
export ZSH_CACHE_DIR="$ZSH_CACHE_HOME" # compatibility variable
export ZSH_COMPDUMP="$ZSH_CACHE_HOME/zcompdump-${SHORT_HOST}-${ZSH_VERSION}"
export HISTFILE="$ZSH_CACHE_HOME/zsh_history"
export HISTCONTROL=ignoredups:erasedups
