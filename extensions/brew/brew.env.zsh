(( ${+commands[brew]} )) || return

# No usage analytics, no "hint" banners after commands
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_ENV_HINTS=1
