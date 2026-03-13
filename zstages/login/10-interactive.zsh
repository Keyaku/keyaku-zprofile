### Last execution to run if in an interactive shell
[[ -o interactive ]] || return

### Print fetch
local fetch="fastfetch"
local fetch_warned="$ZSH_CACHE_HOME/.fetch_warned"
if (( ${+commands[$fetch]} )); then
    $fetch
elif [[ ! -f "$fetch_warned" ]]; then
    print -u2 -f '%s\n' "Info: '$fetch' is not installed." "This message will only show once."
    touch "$fetch_warned"
fi
