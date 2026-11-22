#!/usr/bin/env zsh
#
# One-line installer for keyaku-zprofile:
#   zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Keyaku/keyaku-zprofile/main/conf/install.zsh)"
# Extra arguments go to first_init.zsh, e.g. to answer yes to every step:
#   zsh -c "$(curl -fsSL …/conf/install.zsh)" install -y
#
# Clones the repo into ~/.local/config/zsh (the path first_init.zsh expects) and
# runs first_init.zsh, which fetches the vendored repos, installs packages and sets
# zsh up. Re-running it on an existing clone skips the clone. The repo's
# print_fn isn't available before the clone, so this script prints plainly.

emulate -L zsh
setopt err_exit no_unset

typeset -r REPO_URL="${ZPROFILE_REPO_URL:-https://github.com/Keyaku/keyaku-zprofile.git}"
typeset -r TARGET="$HOME/.local/config/zsh"

function msg { print -u2 -r -- "install: $*" }
function die { msg "$*"; exit 1 }

(( UID >= 1000 )) || die "run this as your regular user, not root (UID=$UID)."

if ! (( ${+commands[git]} )); then
	local hint="your package manager"
	(( ${+commands[pkg]} )) && hint="'pkg install git'"
	(( ${+commands[pacman]} )) && hint="'sudo pacman -S git'"
	(( ${+commands[apt-get]} )) && hint="'sudo apt-get install git'"
	(( ${+commands[dnf]} )) && hint="'sudo dnf install git'"
	(( ${+commands[brew]} )) && hint="'brew install git'"
	die "git is required; install it with $hint and run this again."
fi

if [[ -e "$TARGET" ]]; then
	local origin
	origin=$(git -C "$TARGET" remote get-url origin 2>/dev/null) || origin=
	[[ "$origin" == *keyaku-zprofile* ]] \
		|| die "$TARGET already exists and isn't a keyaku-zprofile clone; move it away and run this again."
	msg "$TARGET is already a clone; skipping to the setup script."
else
	mkdir -p "${TARGET:h}"
	msg "cloning $REPO_URL into $TARGET"
	git clone "$REPO_URL" "$TARGET"
fi

# Offer zsh as the login shell; first_init.zsh doesn't change it.
local zsh_bin=${commands[zsh]}
if [[ "${${SHELL:-}:t}" != zsh && -t 0 ]] && (( ${+commands[chsh]} )); then
	if read -q "?install: make $zsh_bin your login shell (chsh)? [y/N] "; then
		print
		chsh -s "$zsh_bin" || msg "chsh failed; run 'chsh -s $zsh_bin' yourself later."
	else
		print
	fi
fi

msg "running the setup script"
exec zsh "$TARGET/conf/first_init.zsh" "$@"
