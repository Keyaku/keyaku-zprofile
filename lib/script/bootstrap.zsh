# Bootstrap for bin/ scripts under conf/home/bin/.
#
# Not auto-loaded by any zstage. Scripts source this explicitly after their $0
# plugin-standard dance has set THIS / THIS_NAME, to pull in the same lib/core
# and lib/interactive helpers (print_fn, command-has, ask, ...) that an
# interactive shell has.

_zsh_source_dir "${ZDOTDIR}/lib/core" "lib/core"
_zsh_source_dir "${ZDOTDIR}/lib/interactive" "lib/interactive"

function now { date -Iseconds }
