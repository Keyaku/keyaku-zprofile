### Detect if this is an interactive login shell (interactive is implied in .zshrc)
[[ -o login ]] || return

### First-time initialization check
if (( $UID >= 1000 )) && [[ ! -f "$ZDOTDIR/conf/.first_init" ]] || (( 1 != $(cat "$ZDOTDIR/conf/.first_init") )); then
	print -u2 "Warning: The ZSH profile was not initialized. Run the following command to ensure everything works as expected:"
	printf "\t%s\n" "zsh "$ZDOTDIR"/conf/first_init.zsh"
fi

### Print fetch
local fetch="fastfetch"
if (( ${+commands[$fetch]} )); then
	$fetch
else
	print -u2 "Info: '$fetch' is not installed."
fi
