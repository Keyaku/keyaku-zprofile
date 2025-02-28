#######################################
### Homebrew
#######################################

if (( ${+commands[brew]} )); then
	export HOMEBREW_NO_ANALYTICS=1
	export HOMEBREW_NO_ENV_HINTS=1
fi
