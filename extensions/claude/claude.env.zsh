(( ${+commands[claude]} )) || return

export CLAUDE_CONFIG_DIR=${XDG_CONFIG_HOME}/claude
[[ -d $HOME/.claude && ! -L $HOME/.claude ]] && xdg-migrate $HOME/.claude "${CLAUDE_CONFIG_DIR}"

# Claude Code injects shell-function wrappers for grep/find/cat/etc. into every
# subshell that invoke "$CLAUDE_CODE_EXECPATH -G ...". Under glibc-runner on
# Termux that variable points at ld-linux-aarch64.so.1 rather than the real
# claude binary, so each call prints
#   -G: error while loading shared libraries: -G: cannot open shared object file
# Repoint it so the wrappers exec the real binary.
[[ -n $CLAUDE_CODE_EXECPATH && $CLAUDE_CODE_EXECPATH != */claude ]] && \
	export CLAUDE_CODE_EXECPATH=$commands[claude]
