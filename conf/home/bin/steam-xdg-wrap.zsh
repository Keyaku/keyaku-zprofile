#!/usr/bin/env zsh
#
# steam-xdg-wrap.zsh — launch Steam in a rootless (bwrap) mount namespace that
# keeps Steam's XDG-ignoring writes out of the real $HOME. Two modes:
#
#   bind     (default) — $HOME stays the real home; only $XDG_DATA_HOME/pki is
#                        bound over ~/.pki (steamwebhelper hardcodes ~/.pki/nssdb,
#                        XDG-unredirectable). The empty mountpoint bwrap must
#                        create on the real fs is rmdir'd on exit. Zero risk: the
#                        client sees a 100% real home. Downside: the empty ~/.pki
#                        exists for the duration of an always-running Steam.
#
#   private            — a persistent private home at $XDG_STATE_HOME/steam is
#                        bound over $HOME, with only the dirs Steam must share
#                        (library, ~/.steam, cache, ~/.config) bound back to their
#                        real locations. EVERYTHING else a game scatters into $HOME
#                        (~/.pki, ~/.SomeNativeGame, …) lands in the private home
#                        instead — persisted there, never touching the real $HOME.
#                        Caveat: real ~/Documents, ~/Downloads, … are not visible
#                        inside (the private home shadows them); add paths to share
#                        via $STEAM_XDG_SHARE (colon-separated) if a game needs them.
#
# Select with STEAM_XDG_MODE=bind|private (default bind). See the
# steam-mesa-dotdir-culprits / home-dotfile-cleanup project notes.
#
# Invoked by the user-level steam.desktop override (and as the steam:// handler),
# so it must work without a zsh login env: it self-locates $ZDOTDIR from its own
# symlink target. Falls back to launching Steam unwrapped if bwrap / unprivileged
# user namespaces are unavailable, so Steam never breaks.

emulate -L zsh
setopt pipefail

# Standardized $0 handling
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#zero-handling
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

readonly THIS=${0:t}
readonly THIS_NAME=${THIS:r}

# Self-locate the repo from the resolved (symlink-followed) script path:
# $ZDOTDIR/conf/home/bin/<this> -> up four components is $ZDOTDIR. Desktop-file
# launches do not inherit the zsh env, so do not trust an inherited $ZDOTDIR.
: ${ZDOTDIR:=${0:A:h:h:h:h}}

# The real Steam launcher (Arch: /usr/bin/steam -> /usr/lib/steam/steam).
readonly STEAM_REAL=/usr/bin/steam

readonly MODE="${STEAM_XDG_MODE:-bind}"
readonly XDG_DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly XDG_STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
readonly XDG_CACHE="${XDG_CACHE_HOME:-$HOME/.local/cache}"

# Shared script libs (bootstrap pulls in lib/core + lib/interactive: print_fn …).
# Tolerate a missing repo (sparse root ZDOTDIR, broken symlink) by degrading to
# plain stderr — a launcher must never abort just because messaging is absent.
if [[ -r "${ZDOTDIR}/lib/script/bootstrap.zsh" ]]; then
	source "${ZDOTDIR}/lib/script/bootstrap.zsh"
else
	function print_fn { shift 2>/dev/null; print -r -- "${THIS}: $*" >&2 }
fi

# Hand off to the unwrapped launcher, replacing this process.
function exec_unwrapped { exec "$STEAM_REAL" "$@" }

# bwrap + unprivileged user namespaces are required. If either is missing, run
# Steam directly so the user is never locked out of their games.
if ! (( ${+commands[bwrap]} )); then
	print_fn -w "bwrap not found — launching Steam without the XDG namespace."
	exec_unwrapped "$@"
fi
if [[ -r /proc/sys/user/max_user_namespaces ]] && \
   (( $(< /proc/sys/user/max_user_namespaces) == 0 )); then
	print_fn -w "Unprivileged user namespaces are disabled — launching Steam without the XDG namespace."
	exec_unwrapped "$@"
fi

# Avoid the name `status`: it is read-only in zsh.
typeset -a args=(--dev-bind / /)
typeset -i rc=0

case "$MODE" in
	private)
		# Persistent private home; all of Steam's $HOME writes land here unless a
		# path is explicitly shared back to the real home below.
		local priv="$XDG_STATE/steam"
		mkdir -p "$priv"
		args+=(--bind "$priv" "$HOME")

		# Real-home paths Steam must see through the private home. Steam state and
		# the (large, in-place) library live under these; ~/.config carries
		# fontconfig/audio/theme integration; the cache keeps shaders shared.
		typeset -a share=(
			"$HOME/.steam"
			"$XDG_DATA/Steam"
			"$XDG_CACHE"
			"$HOME/.config"
		)
		# User additions (colon-separated), e.g. STEAM_XDG_SHARE=$HOME/Downloads:$HOME/.local/share/vulkan
		[[ -n "$STEAM_XDG_SHARE" ]] && share+=(${(s.:.)STEAM_XDG_SHARE})

		typeset p
		for p in $share; do
			[[ -e "$p" ]] && args+=(--dev-bind "$p" "$p")
		done

		# Recreate the ~/.cache convenience symlink inside the private home so
		# non-XDG-aware apps still reach the shared cache target.
		if [[ -L "$HOME/.cache" ]]; then
			args+=(--symlink "$(readlink "$HOME/.cache")" "$HOME/.cache")
		fi

		bwrap $args -- "$STEAM_REAL" "$@"
		rc=$?
		;;

	bind|*)
		[[ "$MODE" == bind ]] || \
			print_fn -w "Unknown STEAM_XDG_MODE='$MODE' — falling back to 'bind'."
		# Bind the XDG pki store over ~/.pki; bwrap creates the (empty) mountpoint
		# on the real fs, we remove it afterwards.
		local pki_src="$XDG_DATA/pki"
		mkdir -p "$pki_src/nssdb"
		args+=(--bind "$pki_src" "$HOME/.pki")

		bwrap $args -- "$STEAM_REAL" "$@"
		rc=$?

		# Drop the transient mountpoint so ~/.pki does not linger between sessions.
		# Harmless if non-empty (another instance still bound) or already gone.
		rmdir "$HOME/.pki" 2>/dev/null
		;;
esac

exit $rc
