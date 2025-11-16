#######################################
# Misc.
#######################################
alias fileenc='file -bi'
if command-has vim; then
	alias vimenc='vim -c '\''let $enc = &fileencoding | execute "!echo Encoding:  $enc" | q'\'''
fi


# Debugging tools
if command-has valgrind; then
	alias valgrind_custom='valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --dsymutil=yes'
	alias valgrind_massif='valgrind --tool=massif --massif-out-file=massif.out --time-unit=B'
fi

if [[ -o login ]]; then

export SONARLINT_USER_HOME="$XDG_DATA_HOME/sonarlint"

fi
