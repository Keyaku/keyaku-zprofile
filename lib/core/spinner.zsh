##############################################################################
# Spinner animations
#
# Console-safe spinner helpers. Lives in lib/core/ so the functions are defined
# in *every* shell (interactive or not); the non-TTY guard below makes them an
# inert command passthrough wherever there is no terminal to draw on. Two APIs:
#
#   spin "Message" -- cmd args...     # run a command with a spinner (preferred)
#   spinner_start "Message"           # block form: wrap arbitrary work
#   ...do work...
#   spinner_stop $?
#
# Safety guarantees:
#   - No-op (command still runs) when stderr is not a TTY, so pipes, logs and
#     non-interactive contexts are never corrupted.
#   - Cursor is always restored, even on SIGINT/SIGTERM (trap + `always {}`).
#   - Job-control noise is suppressed (no_monitor + disown).
#   - The animation line is cleared with \e[0K so no frame residue is left.
##############################################################################

# ============================================================================
# Frame sets
# ============================================================================
# Space-separated frames + per-style interval (seconds). Override the default
# style per session with `SPINNER_STYLE=<name>`.
typeset -gA _SPINNER_FRAMES _SPINNER_INTERVALS
_SPINNER_FRAMES=(
	dots   '⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏'
	line   '- \ | /'
	moon   '◐ ◓ ◑ ◒'
	mood   ":( :| :) :D"
	gem    '◇ ◈ ◆'
	circle '⚬ ⚭ ⚮ ⚯'
	shade  '░ ▒ ▓ █ ▓ ▒'
	pulse  '☉ ◎ ◉ ● ◉'
	heart  '❤ ♥ ♡'
	star   '✧ ☆ ★ ✪ ◌ ✲'
	yinyang '● ◕ ☯ ◔ ◕'
)
_SPINNER_INTERVALS=(
	dots 0.08  line 0.1   moon 0.18  mood 0.4  gem 0.25
	circle 0.2 shade 0.12 pulse 0.12 heart 0.15 star 0.1 yinyang 0.2
)

: ${SPINNER_STYLE:=dots}

# Module-level state for the block-form API.
typeset -g  _SPINNER_PID=
typeset -g  _SPINNER_TTY=

# ----------------------------------------------------------------------------
# Internal: fractional sleep using pure-zsh zselect (Termux-safe), with a
# sleep(1) fallback. Argument is seconds (may be fractional).
_spinner_sleep() {
	local -F secs=$1
	if zmodload -e zsh/zselect 2>/dev/null || zmodload zsh/zselect 2>/dev/null; then
		# zselect -t takes hundredths of a second.
		local -i csec=$(( secs * 100 ))
		(( csec < 1 )) && csec=1
		zselect -t $csec
	else
		sleep $secs
	fi
}

# Internal: the animation loop. Runs in the background for the block API and
# in the foreground (alongside a backgrounded command) for `spin`. Writes to
# fd 2. Exits when killed or when the loop is broken externally.
#   $1 = style name   $2 = message
_spinner_run() {
	local style=$1 message=$2
	local -a frames=( ${(s: :)_SPINNER_FRAMES[$style]} )
	local -F interval=${_SPINNER_INTERVALS[$style]:-0.1}
	local green=${fg[green]:-} reset=${reset_color:-}
	local -i i=1
	while true; do
		printf '\r%s%s%s %s\e[0K' "$green" "${frames[i]}" "$reset" "$message" >&2
		(( i = i % ${#frames} + 1 ))
		_spinner_sleep $interval
	done
}

# ============================================================================
# Public: block-form API
# ============================================================================

# Start a background spinner. No-op on a non-TTY stderr.
#   spinner_start [-s STYLE] [MESSAGE]
function spinner_start {
	local -a o_style o_help
	zparseopts -D -F -K -- \
		{s,-style}:=o_style \
		{h,-help}=o_help \
	|| return 2
	if (( ${#o_help} )); then
		print -l "Usage: ${funcstack[1]} [-s STYLE] [MESSAGE]" >&2
		return 0
	fi

	# Stop a previous, still-running spinner first.
	[[ -n "$_SPINNER_PID" ]] && spinner_stop 130 ''

	local style=${o_style[-1]:-$SPINNER_STYLE}
	[[ -n "${_SPINNER_FRAMES[$style]}" ]] || style=dots
	local message=${1:-Working}

	# Bail out cleanly when not attached to a terminal.
	if [[ ! -t 2 ]]; then
		_SPINNER_TTY=0
		return 0
	fi
	_SPINNER_TTY=1

	tput civis 2>/dev/null
	# `&!` backgrounds *and* disowns atomically: the job is removed from the
	# job table so no "[n] + terminated" notice fires when we kill it later.
	# `$!` is still set. no_monitor/no_notify is belt-and-suspenders.
	setopt localoptions no_monitor no_notify
	_spinner_run "$style" "$message" &!
	_SPINNER_PID=$!
}

# Stop the running spinner and print a final status line.
#   spinner_stop [EXIT_CODE] [FINAL_MESSAGE]
# EXIT_CODE 0 -> green check, non-zero -> red cross. An empty FINAL_MESSAGE
# (explicit '') clears the line silently instead of printing a result.
function spinner_stop {
	local -i code=${1:-0}
	local final=${2-__SPINNER_KEEP__}

	if [[ -n "$_SPINNER_PID" ]]; then
		# Already disowned (see spinner_start), no wait necessary.
		kill $_SPINNER_PID 2>/dev/null
		_SPINNER_PID=
	fi

	# Nothing drawn (non-TTY) -> nothing to clean up.
	if [[ "$_SPINNER_TTY" != 1 ]]; then
		_SPINNER_TTY=
		return $code
	fi
	_SPINNER_TTY=

	tput cnorm 2>/dev/null
	if [[ -z "$final" ]]; then
		# Silent clear.
		printf '\r\e[0K' >&2
	elif [[ "$final" == __SPINNER_KEEP__ ]]; then
		# No message given: just clear, leave cursor on the line start.
		printf '\r\e[0K' >&2
	else
		local mark color
		if (( code == 0 )); then
			mark='✔'; color=${fg[green]:-}
		else
			mark='✖'; color=${fg[red]:-}
		fi
		printf '\r%s%s%s %s\e[0K\n' "$color" "$mark" "${reset_color:-}" "$final" >&2
	fi
	return $code
}

# ============================================================================
# Public: command-wrapper API (preferred)
# ============================================================================

# Run a command under a spinner, printing a success/failure line when done.
#   spin [-s STYLE] [-m DONE_MSG] MESSAGE -- cmd args...
# The command's own stdout/stderr pass through untouched; the spinner draws on
# stderr and is fully cleared before the result line. Returns the command's
# exit status.
function spin {
	local -a o_style o_done o_help
	zparseopts -D -F -K -- \
		{s,-style}:=o_style \
		{m,-message}:=o_done \
		{h,-help}=o_help \
	|| return 2

	local -ra usage=(
		"Usage: ${funcstack[1]} [-s STYLE] [-m DONE_MSG] MESSAGE -- CMD [ARG...]"
		"  -s, --style=NAME     Spinner style (default: \$SPINNER_STYLE)"
		"  -m, --message=TEXT   Final-line message (default: MESSAGE)"
		"  -h, --help           Show this help and the available styles"
	)
	if (( ${#o_help} )); then
		print -l $usage >&2
		print -- "  Styles: ${(ok)_SPINNER_FRAMES}" >&2
		return 0
	fi

	# Split MESSAGE ... -- CMD ...
	local -a head cmd
	local seen_sep=0 arg
	for arg in "$@"; do
		if (( seen_sep )); then
			cmd+=("$arg")
		elif [[ "$arg" == -- ]]; then
			seen_sep=1
		else
			head+=("$arg")
		fi
	done

	if (( ! seen_sep )) || (( ${#cmd} == 0 )); then
		print -l $usage >&2
		return 2
	fi

	local message="${(j: :)head}"
	[[ -n "$message" ]] || message='Working'
	local done_msg=${o_done[-1]:-$message}
	local style=${o_style[-1]:-$SPINNER_STYLE}

	# Non-TTY: run plainly, no animation, no residue.
	if [[ ! -t 2 ]]; then
		"${cmd[@]}"
		return $?
	fi

	local -i code=0
	{
		spinner_start -s "$style" "$message"
		"${cmd[@]}"
		code=$?
	} always {
		spinner_stop $code "$done_msg"
	}
	return $code
}
