##############################################################################
# Spinner animations
#
# Console-safe spinner helpers. Lives in lib/core/ so the functions are defined
# in *every* shell (interactive or not); the non-TTY guard below makes them an
# inert command passthrough wherever there is no terminal to draw on. Two APIs:
#
#   spin "Message" -- cmd args...     # run a command with a spinner (preferred)
#   spinner_start "Message"           # block form: wrap arbitrary work
#   print -- "result line"            # ANY output interleaves cleanly (see below)
#   spinner_stop $?
#
# Transparent output
# -------------------
# While a spinner is active, the shell's stdout AND stderr are funnelled into a
# single renderer process that owns the terminal: it animates the spinner and
# relays the caller's output above it. So plain `print`, `echo`, `print_fn`, and
# even external-command output interleave with no helper. `spinner_print` is
# kept only as a back-compat alias for plain `print`.
#
# Caveats:
#   - External (C) programs block-buffer when their stdout is a pipe rather than
#     a tty, so their output may appear in chunks or only at exit. zsh builtins
#     (print/echo/print_fn) write immediately and are unaffected.
#   - Partial lines (`print -n`, single-line progress bars) are held by the
#     renderer until a newline arrives.
#
# Safety guarantees:
#   - No-op (command still runs) when stderr is not a TTY, so pipes, logs and
#     non-interactive contexts are never corrupted.
#   - fd 1/2 are always restored, even on SIGINT (TRAPINT) or error (`spin`'s
#     `always {}`), so the shell can never end up writing into a dead pipe.
#   - The cursor is hidden/restored by the renderer; the spinner row is wiped
#     with \e[0K so no frame residue is left.
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
typeset -g  _SPINNER_PID=          # renderer pid
typeset -g  _SPINNER_TTY=          # 1 = active on a tty, 0 = inert, '' = stopped
typeset -gi _SPINNER_O1 _SPINNER_O2 _SPINNER_FD   # saved fd1, fd2, FIFO write end
typeset -g  _SPINNER_OLD_TRAPINT=
typeset -gi _SPINNER_HAD_TRAPINT=0

# ----------------------------------------------------------------------------
# Internal: the renderer. Owns the terminal. Reads the caller's output from its
# stdin (the FIFO) and draws to the real tty (fd passed as $3). Relays complete
# lines above the spinner and animates on a timer in between.
#   $1 = style   $2 = message   $3 = tty fd
_spinner_render() {
	emulate -L zsh
	zmodload zsh/system 2>/dev/null
	local style=$1 message=$2
	local -i tty=$3
	local -a frames=( ${(s: :)_SPINNER_FRAMES[$style]} )
	local -F interval=${_SPINNER_INTERVALS[$style]:-0.1}
	local green=${fg[green]:-} reset=${reset_color:-}
	local -i i=1 ret
	local buf='' chunk line

	printf '\e[?25l' >&$tty                 # hide cursor
	while true; do
		sysread -t $interval chunk
		ret=$?
		if (( ret == 0 )); then             # data: relay complete lines
			buf+=$chunk
			while [[ $buf == *$'\n'* ]]; do
				line=${buf%%$'\n'*}
				buf=${buf#*$'\n'}
				printf '\r\e[0K%s\n' "$line" >&$tty
			done
			# redraw the spinner immediately so it never disappears
			printf '\r%s%s%s %s\e[0K' "$green" "${frames[i]}" "$reset" "$message" >&$tty
		elif (( ret == 4 )); then           # timeout: advance a frame
			printf '\r%s%s%s %s\e[0K' "$green" "${frames[i]}" "$reset" "$message" >&$tty
			(( i = i % ${#frames} + 1 ))
		else                                # EOF (5) / error: flush + leave
			[[ -n $buf ]] && printf '\r\e[0K%s\n' "$buf" >&$tty
			break
		fi
	done
	printf '\r\e[0K\e[?25h' >&$tty          # wipe row, restore cursor
}

# ============================================================================
# Public: block-form API
# ============================================================================

# Start a spinner and funnel the shell's stdout/stderr through it. No-op on a
# non-TTY stderr.
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
	[[ "$_SPINNER_TTY" == 1 ]] && spinner_stop 130 ''

	local style=${o_style[-1]:-$SPINNER_STYLE}
	[[ -n "${_SPINNER_FRAMES[$style]}" ]] || style=dots
	local message=${1:-Working}

	# Bail out cleanly when not attached to a terminal.
	if [[ ! -t 2 ]]; then
		_SPINNER_TTY=0
		return 0
	fi

	# Rendezvous FIFO. On any setup failure, degrade to the inert path.
	local fifo
	fifo=$(mktemp -u "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/spinner.XXXXXX") || { _SPINNER_TTY=0; return 0; }
	mkfifo -m 600 "$fifo" 2>/dev/null || { _SPINNER_TTY=0; return 0; }

	# Save the real stdout/stderr; the renderer draws to the saved stderr.
	exec {_SPINNER_O1}>&1 {_SPINNER_O2}>&2

	# Launch the renderer reading the FIFO. `&!` disowns so no job-control
	# noise fires when it exits; `$!` still gives us a pid to wait on.
	setopt localoptions no_monitor no_notify
	_spinner_render "$style" "$message" $_SPINNER_O2 < "$fifo" &!
	_SPINNER_PID=$!

	# Open the write end (unblocks the renderer's FIFO open), then unlink the
	# path — both ends keep it alive.
	exec {_SPINNER_FD}> "$fifo"
	rm -f "$fifo"

	# Funnel everything the caller prints into the renderer.
	exec 1>&$_SPINNER_FD 2>&$_SPINNER_FD
	_SPINNER_TTY=1

	# Restore fds even if the block is interrupted with Ctrl-C.
	_SPINNER_HAD_TRAPINT=$(( $+functions[TRAPINT] ))
	_SPINNER_OLD_TRAPINT=${functions[TRAPINT]}
	TRAPINT() {
		spinner_stop 130 ''
		return $(( 128 + ${1:-2} ))
	}
}

# Stop the spinner, restore the shell's fds, and print a final status line.
# Idempotent: safe to call twice (e.g. from TRAPINT then explicitly).
#   spinner_stop [EXIT_CODE] [FINAL_MESSAGE]
# EXIT_CODE 0 -> green check, non-zero -> red cross. An empty FINAL_MESSAGE
# (explicit '') stops silently with no result line.
function spinner_stop {
	local -i code=${1:-0}
	local final=${2-__SPINNER_KEEP__}

	# Inert (non-tty start) or already stopped: nothing to tear down.
	if [[ "$_SPINNER_TTY" != 1 ]]; then
		_SPINNER_TTY= _SPINNER_PID=
		return $code
	fi

	# Restore fds *first* so the renderer's FIFO sees EOF, then reap it.
	exec 1>&$_SPINNER_O1 2>&$_SPINNER_O2
	exec {_SPINNER_O1}>&- {_SPINNER_O2}>&-
	exec {_SPINNER_FD}>&-
	[[ -n "$_SPINNER_PID" ]] && wait $_SPINNER_PID 2>/dev/null

	# Restore any pre-existing INT trap.
	if (( _SPINNER_HAD_TRAPINT )); then
		functions[TRAPINT]=$_SPINNER_OLD_TRAPINT
	else
		unfunction TRAPINT 2>/dev/null
	fi
	_SPINNER_OLD_TRAPINT= _SPINNER_HAD_TRAPINT=0

	_SPINNER_TTY= _SPINNER_PID=

	# Renderer already wiped its row and restored the cursor; the cursor sits at
	# column 0 of that cleared line, so the final status prints right there.
	if [[ "$final" != __SPINNER_KEEP__ && -n "$final" ]]; then
		local mark color
		if (( code == 0 )); then
			mark='✔'; color=${fg[green]:-}
		else
			mark='✖'; color=${fg[red]:-}
		fi
		printf '%s%s%s %s\n' "$color" "$mark" "${reset_color:-}" "$final" >&2
	fi
	return $code
}

# Back-compat: output now interleaves transparently, so a plain `print` works
# inside a spinner. This remains for existing callers.
#   spinner_print [print-args...]
function spinner_print {
	print -r -- "$@"
}

# ============================================================================
# Public: command-wrapper API (preferred)
# ============================================================================

# Run a command under a spinner, printing a success/failure line when done.
#   spin [-s STYLE] [-m DONE_MSG] MESSAGE -- cmd args...
# The command's stdout/stderr interleave above the spinner (see header); the
# `always {}` block guarantees fd restore on any exit path. Returns the
# command's exit status.
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
