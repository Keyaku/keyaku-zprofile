# Set CLAUDE_CONFIG_DIR when Claude is installed OR its XDG config already
# exists. The latter clause matters because `claude` may not be on $PATH yet at
# login-shell time (when the GUI/session env is captured) and because the config
# dir outlives the ~/.claude symlink — so the var still lands in the session env
# and survives the symlink's removal, without polluting systems that have
# neither.
(( ${+commands[claude]} )) || [[ -d ${XDG_CONFIG_HOME}/claude ]] || return
export CLAUDE_CONFIG_DIR=${XDG_CONFIG_HOME}/claude
[[ -d $HOME/.claude && ! -L $HOME/.claude ]] && xdg-migrate $HOME/.claude "${CLAUDE_CONFIG_DIR}"

(( ${+commands[claude]} )) || return

# Claude Code injects shell-function wrappers for grep/find/cat/etc. into every
# subshell that invoke "$CLAUDE_CODE_EXECPATH -G ...". Under glibc-runner on
# Termux that variable points at ld-linux-aarch64.so.1 rather than the real
# claude binary, so each call prints
#   -G: error while loading shared libraries: -G: cannot open shared object file
# Repoint it so the wrappers exec the real binary.
[[ -n $CLAUDE_CODE_EXECPATH && $CLAUDE_CODE_EXECPATH != */claude ]] && \
	export CLAUDE_CODE_EXECPATH=$commands[claude]
