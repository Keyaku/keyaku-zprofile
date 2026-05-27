# Sandbox detection + host-side execution helpers.
#
# Not auto-loaded by any zstage. Scripts under conf/home/bin/ (or anything that
# sources lib/script/bootstrap.zsh) opt in with:
#
#   source "${ZDOTDIR}/lib/script/sandbox.zsh"
#
# The detector set is open: every entry in SANDBOX_DETECTORS resolves to a pair
# of functions, _sandbox_detect_<name> (returns 0 if active) and an optional
# _sandbox_run_<name> CMD... (runs CMD on the host equivalent). Add a new
# sandbox by appending its name to SANDBOX_DETECTORS and defining the matching
# detector (and, if relevant, runner).
#
# Public API (all `sandbox_`-prefixed to avoid collisions with third-party
# commands like `sandbox`, `sandboxed`, `sandbox-exec`):
#   sandbox_list                 -> print detected sandbox names, one per line
#   sandbox_list -f|--force      -> drop the cached result and re-detect
#   sandbox_in [NAME...]         -> no args: exit 0 if any sandbox is active
#                                   with args: exit 0 if ANY of NAME is active
#   sandbox_run CMD [ARG...]     -> run CMD on the host when sandboxed; else direct

typeset -agU SANDBOX_LIST=()
typeset -agU SANDBOX_DETECTORS=(flatpak)
typeset -gi  _SANDBOX_CACHED=0

# --- Flatpak --------------------------------------------------------------

function _sandbox_detect_flatpak {
	[[ -f /.flatpak-info ]]
}

function _sandbox_run_flatpak {
	if (( $+commands[flatpak-spawn] )); then
		flatpak-spawn --host "$@"
	elif (( $+commands[host-spawn] )); then
		host-spawn "$@"
	else
		print -u2 "sandbox_run: no flatpak-spawn / host-spawn available to reach the host"
		return 127
	fi
}

# --- Core -----------------------------------------------------------------

function _sandbox_refresh {
	SANDBOX_LIST=()
	local d
	for d in $SANDBOX_DETECTORS; do
		(( $+functions[_sandbox_detect_${d}] )) || continue
		"_sandbox_detect_${d}" 2>/dev/null && SANDBOX_LIST+=("$d")
	done
	_SANDBOX_CACHED=1
}

function sandbox_list {
	local -ra usage=(
		"Usage: ${funcstack[1]} [-f|--force]"
		"  Print detected sandbox names, one per line."
		"  -f|--force  drop cached detection and re-probe"
	)
	local -a o_help o_force
	zparseopts -D -F -K -- h=o_help -help=o_help f=o_force -force=o_force || {
		>&2 print -l $usage
		return 2
	}
	(( $#o_help )) && { >&2 print -l $usage; return 0 }
	(( $#o_force )) && _SANDBOX_CACHED=0

	(( _SANDBOX_CACHED )) || _sandbox_refresh
	print -l -- $SANDBOX_LIST
}

function sandbox_in {
	(( _SANDBOX_CACHED )) || _sandbox_refresh

	if ! (( $# )); then
		(( ${#SANDBOX_LIST} ))
		return $?
	fi

	local q
	for q in "$@"; do
		(( ${SANDBOX_LIST[(Ie)$q]} )) && return 0
	done
	return 1
}

function sandbox_run {
	if ! (( $# )); then
		>&2 print "Usage: ${funcstack[1]} CMD [ARG...]"
		return 2
	fi
	(( _SANDBOX_CACHED )) || _sandbox_refresh

	local s
	for s in $SANDBOX_LIST; do
		if (( $+functions[_sandbox_run_${s}] )); then
			"_sandbox_run_${s}" "$@"
			return $?
		fi
	done
	"$@"
}
