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

# ── Desktop notifications ─────────────────────────────────────────────────────
# Best-effort, DE-agnostic notifications so the user knows updates started and
# finished. Discover's own "task" indicator is driven by PackageKit's internal
# update jobs and can't be fed from an external CLI run, so we surface progress
# this way instead.
#
# Backends are tried in order of preference; the first one present wins:
#   notify-send  freedesktop standard, ships with libnotify (any DE)
#   dunstify     dunst's notify-send-compatible client
#   gdbus        raw freedesktop Notifications D-Bus call (no extra package)
#   kdialog      KDE fallback (passive popup; can't reuse a single bubble)
# Where supported (notify-send/dunstify/gdbus) a single notification is reused
# so the "start" bubble morphs into the "finished" result rather than stacking.
#
# Urgency is the freedesktop scale: low | normal | critical (no "high"). In a
# systemd user service the session bus address is normally inherited; if it
# isn't (no graphical session), every backend fails and we carry on.
local -i notif_id=0
local _notify_backend=""
_notify_detect() {
	local b
	for b in notify-send dunstify gdbus kdialog; do
		command-has $b && { _notify_backend=$b; return 0; }
	done
	return 1
}
notify() {
	[[ -n $_notify_backend ]] || _notify_detect || return 0
	local urgency=$1 title=$2 body=$3 icon=${4:-system-software-update}
	local out
	case $_notify_backend in
		notify-send|dunstify)
			local -a nargs=(--app-name=Maintenance --icon="$icon" --urgency="$urgency" --print-id)
			(( notif_id )) && nargs+=(--replace-id="$notif_id")
			out=$($_notify_backend $nargs "$title" "$body" 2>/dev/null) && notif_id=$out
			;;
		gdbus)
			out=$(gdbus call --session \
				--dest org.freedesktop.Notifications \
				--object-path /org/freedesktop/Notifications \
				--method org.freedesktop.Notifications.Notify \
				Maintenance "$notif_id" "$icon" "$title" "$body" "[]" "{}" 0 2>/dev/null) || return 0
			out=${out#*uint32 }
			notif_id=${out%%[^0-9]*}
			;;
		kdialog)
			kdialog --title "$title" --icon "$icon" --passivepopup "$body" 10 2>/dev/null
			;;
	esac
}

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
notify low "Maintenance started" "Running ${#tasks} task(s): ${tasks}…"

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
if (( overall_rc == 0 )); then
	notify low "Maintenance finished" "All ${#tasks} task(s) completed successfully." "system-software-update"
else
	notify normal "Maintenance failed" "Some task(s) failed (rc=$overall_rc). See: journalctl --user -t maintenance" "dialog-error"
fi
exit $overall_rc
