### Last execution to run if in an interactive shell
[[ -o interactive ]] || return

### Print fetch
local fetch="fastfetch"
if (( ${+commands[$fetch]} )); then
	$fetch
else
	print -u2 "Info: '$fetch' is not installed."
fi
