#!/usr/bin/env zsh
# User maintenance script: invoked by maintenance.service on login and around
# sleep/wake. Idempotent and throttled so duplicate triggers are harmless.
#
# To add a task: append the function name to the `tasks` array below. Each
# task is just a zsh function (or external command) already on PATH or sourced
# in the "Environment" section. Tasks run in order; a failure is logged but
# does not abort the remaining tasks. The throttle stamp is touched only when
# every task succeeded.

emulate -L zsh
set -u
zmodload zsh/datetime 2>/dev/null

: ${XDG_STATE_HOME:=$HOME/.local/state}
: ${ZDOTDIR:=${XDG_CONFIG_HOME:-$HOME/.local/config}/zsh}

local -r state_dir="$XDG_STATE_HOME/maintenance"
local -r stamp="$state_dir/last-run"
local -ri throttle_secs=3600

mkdir -p -- "$state_dir"

if [[ -f "$stamp" ]]; then
	local -i age=$(( EPOCHSECONDS - $(stat -c %Y "$stamp") ))
	if (( age < throttle_secs )); then
		print -r -- "maintenance: skipped (last run ${age}s ago, throttle ${throttle_secs}s)"
		exit 0
	fi
fi

# ── Environment ──────────────────────────────────────────────────────────────
# Source whatever the tasks need. Keep this section minimal.
autoload -Uz colors && colors
local -ra zlibs=(
	lib/core/functions.zsh
	lib/core/strings.zsh
	lib/interactive/commands.zsh
	extensions/flatpak/flatpak.plugin.zsh
)
local libfile
for libfile in ${zlibs}; do
	source "$ZDOTDIR/$libfile"
done

# ── Task list ────────────────────────────────────────────────────────────────
# Add new task names here. Each must be callable (function or command).
local -a tasks=(
	flatpak-update
)

# ── Runner ───────────────────────────────────────────────────────────────────
run_task() {
	local task=$1
	if ! command-has $task; then
		print -ru2 -- "maintenance: [$task] not available, skipping"
		return 127
	fi
	print -r -- "maintenance: [$task] start"
	local -i t0=$EPOCHSECONDS rc=0
	$task || rc=$?
	print -r -- "maintenance: [$task] done rc=$rc ($(( EPOCHSECONDS - t0 ))s)"
	return $rc
}

print -r -- "maintenance: starting at $(date -Iseconds) (${#tasks} task(s))"

local -i overall_rc=0 task_rc=0
local task
for task in $tasks; do
	run_task $task
	task_rc=$?
	(( task_rc != 0 )) && overall_rc=$task_rc
done

if (( overall_rc == 0 )); then
	: > "$stamp"
fi

print -r -- "maintenance: finished rc=$overall_rc"
exit $overall_rc
