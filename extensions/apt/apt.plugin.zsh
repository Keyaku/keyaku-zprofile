# Select exclusively Debian or Ubuntu (or Termux)
whatami Debian Ubuntu Android || return

(( ${+commands[apt]} || ${+commands[apt-get]} )) || return

# On Termux pacman builds, apt may linger but is not the active manager —
# the pacman db directory is the authoritative signal.
[[ -d "${TERMUX__PREFIX:-}/var/lib/pacman/local" ]] && return

local SUDO=$(whatami Android || echo "sudo ")

### APT-related aliases
alias apt-update="${SUDO}apt update"
alias apt-upgrade="${SUDO}apt upgrade -y --auto-remove"
alias apt-install="${SUDO}apt install --auto-remove"
alias apt-remove="${SUDO}apt remove --auto-remove"
alias apt-purge="apt-remove --purge"
alias apt-autoremove="${SUDO}apt autoremove --purge"
alias apt-all="apt-update && apt-upgrade"
alias apt-clean="${SUDO}apt-get clean"
alias apt-markauto="${SUDO}apt-mark auto"
alias apt-hold="${SUDO}apt-mark hold"
alias apt-unhold="${SUDO}apt-mark unhold"
alias apt-holds="apt-mark showhold"

# Leaf orphans: installed library packages with no installed reverse-deps.
# Scans every libs/oldlibs package, so it can take a while — wrap the loop in
# `spin` (lib/interactive/spinner.zsh) for a liveness indicator.
function apt-orphans {
	local -a libs
	libs=( ${(f)"$(dpkg-query -W -f='${Package} ${Section} ${Essential} ${Priority}\n' | awk '$2~/libs|oldlibs/ && $3!="yes" && $4!~/required|important/{print $1}')"} )
	local -ir total=${#libs}

	spinner_start "Scanning ${total} library packages for orphans"
	local p
	for p in $libs; do
		apt-cache rdepends --installed "$p" 2>/dev/null | sed '1,2d' | grep -q . \
			|| print -- "$p"
	done
	spinner_stop 0 "Scanned ${total} library packages"
}

# apt-cache search with an [installed] marker on already-installed packages.
function apt-search {
	check_argc $# 1 || return
	local line pkg
	apt-cache search -- "$@" | while IFS= read -r line; do
		pkg=${line%% *}
		if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q '^install ok installed$'; then
			print -- "[installed] $line"
		else
			print -- "            $line"
		fi
	done
}

# Explain why a package is installed: install-state, auto/manual, reverse deps.
function apt-why {
	check_argc $# 1 1 || return
	local -r pkg=$1
	if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q '^install ok installed$'; then
		print_fn -e "$pkg is not installed"
		return 1
	fi
	local mark=manual
	apt-mark showauto 2>/dev/null | grep -qx "$pkg" && mark=auto
	print_fn -i "$pkg (${mark})"
	print_fn -i "Reverse dependencies (installed):"
	apt-cache rdepends --installed "$pkg" 2>/dev/null | sed '1,2d' | sort -u
}

# Which installed package owns the given path(s)?
function apt-owns {
	check_argc $# 1 || return
	dpkg -S -- "$@"
}

# List files shipped by an installed package (optionally grep-filtered).
function apt-files {
	check_argc $# 1 2 || return
	if (( $# == 2 )); then
		dpkg -L -- "$1" | grep -- "$2"
	else
		dpkg -L -- "$1"
	fi
}

# Pretty-print apt history (install/remove/upgrade actions) from apt's log.
function apt-history {
	local -a logs
	logs=( /var/log/apt/history.log(N) /var/log/apt/history.log.*.gz(N) )
	(( ${#logs} )) || { print_fn -w "No apt history logs found."; return 1; }

	local f
	for f in $logs; do
		if [[ $f == *.gz ]]; then zcat -- "$f"; else cat -- "$f"; fi
	done | awk '
		/^Start-Date:/ { sub(/^Start-Date: */, ""); date=$0 }
		/^Commandline:/ { sub(/^Commandline: */, ""); cmd=$0 }
		/^Requested-By:/ { sub(/^Requested-By: */, ""); who=$0 }
		/^End-Date:/ {
			printf "%s  %s%s\n", date, (who ? "(" who ") " : ""), cmd
			date=""; cmd=""; who=""
		}
	'
}

# Top-N installed packages by installed size (default 20).
function apt-size {
	check_argc $# 0 1 || return
	local -ir n=${1:-20}
	dpkg-query -W -f='${Installed-Size}\t${Package}\n' \
		| sort -rn | head -n $n \
		| awk '{ printf "%8.1f MiB  %s\n", $1/1024, $2 }'
}
