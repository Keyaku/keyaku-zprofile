#######################################
# Misc.
#######################################
alias fileenc='file -bi'
if command_has vim; then
	alias vimenc='vim -c '\''let $enc = &fileencoding | execute "!echo Encoding:  $enc" | q'\'''
fi


# Debugging tools
if command_has valgrind; then
	alias valgrind_custom='valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --dsymutil=yes'
	alias valgrind_massif='valgrind --tool=massif --massif-out-file=massif.out --time-unit=B'
fi
