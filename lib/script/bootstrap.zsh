# Bootstrap for bin/ scripts under conf/home/bin/.
#
# Not auto-loaded by any zstage. Scripts source this explicitly after their $0
# plugin-standard dance has set THIS / THIS_NAME, to pull in the same lib/core
# and lib/interactive helpers (print_fn, command-has, ask, ...) that an
# interactive shell has.

_zsh_source_dir "${ZDOTDIR}/lib/core" "lib/core"
_zsh_source_dir "${ZDOTDIR}/lib/interactive" "lib/interactive"

zmodload zsh/datetime

function now {
	# strftime's `%z` emits `+0100`; splice to ISO-8601 `+01:00` to match `date -Iseconds`.
	local s
	strftime -s s '%FT%T%z' $EPOCHSECONDS
	print -- "${s[1,-3]}:${s[-2,-1]}"
}
