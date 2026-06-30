# ============================================================================
# zdefer — phase-keyed deferred-task registry
# ============================================================================
#
# Extensions and plugins are sourced (zstages/rc/10-setup.zsh) *before* OMZ runs
# `compinit` (zstages/rc/25-omz-load.zsh), so any `compdef` call made at source
# time silently no-ops — `compdef` does not exist yet. `zdefer` lets a caller
# queue such work against a named "phase" and have it run reliably once that
# phase is ready, with a run-now fast path when the phase is already satisfied.
#
# A "phase" is a label whose readiness is testable by `_zdefer_ready <phase>`.
# Only the `compinit` phase is wired today (ready when `compdef` exists), but the
# mechanism is generic — future phases (post-p10k, post-bashcompinit) reuse it.

# Per-phase stacks of queued tasks. Each element is a single ${(q)}-quoted
# command line, eval'd in push order at flush time.
typeset -ga _ZDEFER_compinit

# Phase readiness probe. Returns 0 when <phase> is satisfied (its queued tasks
# can run now), non-zero otherwise. Unknown phases are never ready.
function _zdefer_ready {
	case "$1" in
		compinit) (( $+functions[compdef] )) ;;
		*) return 1 ;;
	esac
}

# zdefer <phase> CMD [ARG...]
#   Queue CMD ARG... to run when <phase> is flushed. If <phase> is already
#   satisfied, run CMD immediately so callers never care about ordering.
function zdefer {
	if (( $# < 2 )); then
		print_fn -e "usage: ${funcstack[1]} <phase> CMD [ARG...]"
		return 1
	fi

	local -r phase="$1"; shift

	# Run-now fast path: phase already ready, no need to queue.
	if _zdefer_ready "$phase"; then
		"$@"
		return
	fi

	# Phase not ready: stash the task, ${(q)}-quoted so args survive eval.
	local -r stackname="_ZDEFER_${phase}"
	typeset -ga "$stackname"
	eval "${stackname}+=( \${(j: :)\${(q)@}} )"
}

# zdefer_flush <phase>
#   Run, in push order, then clear every task queued for <phase>. Idempotent:
#   the stack is cleared after running, so a double-flush is a harmless no-op.
function zdefer_flush {
	if (( $# != 1 )); then
		print_fn -e "usage: ${funcstack[1]} <phase>"
		return 1
	fi

	local -r phase="$1"
	local -r stackname="_ZDEFER_${phase}"
	local -a tasks=( "${(@P)stackname}" )

	# Clear first so a task that re-defers against the same phase re-queues
	# cleanly instead of being wiped by the post-run reset.
	set -A "$stackname"

	local task
	for task in "${tasks[@]}"; do
		eval "$task"
	done
}
