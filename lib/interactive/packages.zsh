# ============================================================================
# System package manager
# ============================================================================

# Package managers pkg-install knows, in detection order (the first one found
# wins; Homebrew comes last so a Linux system's own manager takes precedence).
typeset -ga _PKG_MANAGERS=(pacman apt-get dnf zypper apk xbps-install brew)

# Sets REPLY to this system's package manager, detected by which binary exists
# rather than by distro name (fails when none is known). Termux's `pkg` is only
# considered on Android, where it's the native one.
function _pkg_manager {
	if [[ -n "$_PKG_MANAGER" ]]; then
		REPLY=$_PKG_MANAGER
		return 0
	fi
	local m
	if whatami Android && (( ${+commands[pkg]} )); then
		m=pkg
	else
		for m in ${_PKG_MANAGERS} ''; do
			[[ -n "$m" ]] && (( ${+commands[$m]} )) && break
		done
	fi
	[[ -n "$m" ]] || return 1
	typeset -g _PKG_MANAGER=$m
	REPLY=$m
}

# Sets REPLY to NAME's package name for MANAGER from $ZDOTDIR/conf/packages.tsv:
# NAME itself when the table doesn't list it or says "=", and fails when it
# says "-" (not available there).
function _pkg_name {
	local -r manager=$1 name=$2
	if (( ! ${+_PKG_NAMES} )); then
		typeset -gA _PKG_NAMES=()
		local -a header fields
		local line
		local -i i
		while IFS= read -r line; do
			[[ -z "$line" || "$line" == \#* ]] && continue
			fields=("${(@ps:\t:)line}")
			if (( ! ${#header} )); then
				header=($fields)
				continue
			fi
			for (( i = 2; i <= ${#header}; i++ )); do
				_PKG_NAMES[${header[$i]}:${fields[1]}]=${fields[$i]}
			done
		done < "$ZDOTDIR/conf/packages.tsv"
	fi
	local mapped=${_PKG_NAMES[$manager:$name]:-=}
	[[ "$mapped" == - ]] && return 1
	[[ "$mapped" == = ]] && mapped=$name
	REPLY=$mapped
}

# Succeeds when PKG (a package name for MANAGER) is installed
function _pkg_installed {
	local -r manager=$1 pkg=$2
	case $manager in
	pacman )       pacman -Q -- "$pkg" &>/dev/null ;;
	apt-get | pkg ) [[ "$(dpkg-query -W -f='${Status}' -- "$pkg" 2>/dev/null)" == *" installed" ]] ;;
	dnf | zypper ) rpm -q -- "$pkg" &>/dev/null ;;
	apk )          apk info -e -- "$pkg" &>/dev/null ;;
	xbps-install ) xbps-query -- "$pkg" &>/dev/null ;;
	brew )         brew list -- "$pkg" &>/dev/null ;;
	* )            return 1 ;;
	esac
}

# Installs packages with the system's package manager
function pkg-install {
	local -r usage=(
		"Usage: $(get_funcname) [OPTION...] PACKAGE..."
		"\t[-h|--help]    : Print this help message"
		"\t[-n|--dry-run] : Print the commands instead of running them"
		"\t[-y|--yes]     : Don't ask the package manager for confirmation"
		"\t[-u|--upgrade] : Refresh the package lists and upgrade the system first (only when something needs installing)"
		"\t[-w|--which]   : Print the detected package manager and exit"
		"PACKAGE names that differ per package manager are mapped through \$ZDOTDIR/conf/packages.tsv;"
		"packages already installed are skipped."
	)

	local f_help f_dryrun f_yes f_upgrade f_which
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{n,-dry-run}=f_dryrun \
		{y,-yes}=f_yes \
		{u,-upgrade}=f_upgrade \
		{w,-which}=f_which \
		|| return 1

	if (( ${#f_help} )); then
		>&2 print -l $usage
		return 0
	fi

	_pkg_manager || { print_fn -e "No supported package manager found (${_PKG_MANAGERS}, pkg)"; return 1 }
	local -r manager=$REPLY
	if (( ${#f_which} )); then
		print -r -- "$manager"
		return 0
	fi
	check_argc $# 1 || { >&2 print -l $usage; return 1 }

	local name
	local -a missing=() unavailable=()
	for name in "$@"; do
		if ! _pkg_name "$manager" "$name"; then
			unavailable+=("$name")
			continue
		fi
		_pkg_installed "$manager" "$REPLY" || missing+=("$REPLY")
	done
	(( ${#unavailable} )) && print_fn -w "Not available through $manager, skipped: ${unavailable}"
	if (( ! ${#missing} )); then
		print_fn -i "Nothing to install: all requested packages are already installed"
		return 0
	fi

	# Root-only managers go through sudo; Homebrew and Termux's pkg refuse it
	local -a run=()
	(( ${#f_dryrun} )) && run=(print -r --)
	local -a elevate=()
	if (( EUID != 0 )) && [[ "$manager" != (brew|pkg) ]]; then
		(( ${+commands[sudo]} )) || { print_fn -e "$manager needs root, and sudo isn't installed"; return 1 }
		elevate=(sudo)
	fi
	local -i yes=${#f_yes}

	local -a upgrade=() install=()
	case $manager in
	pacman )
		upgrade=(pacman -Syu)
		install=(pacman -S --needed)
		(( yes )) && { upgrade+=(--noconfirm); install+=(--noconfirm) }
	;;
	apt-get )
		upgrade=(apt-get update)
		install=(apt-get install)
		(( yes )) && install+=(-y)
	;;
	dnf )
		upgrade=(dnf upgrade --refresh)
		install=(dnf install)
		(( yes )) && { upgrade+=(-y); install+=(-y) }
	;;
	zypper )
		upgrade=(zypper refresh)
		install=(zypper)
		(( yes )) && install+=(--non-interactive)
		install+=(install)
	;;
	apk )
		upgrade=(apk upgrade --update-cache)
		install=(apk add)
	;;
	xbps-install )
		upgrade=(xbps-install -Su)
		install=(xbps-install -S)
		(( yes )) && { upgrade+=(-y); install+=(-y) }
	;;
	brew )
		upgrade=(brew update)
		install=(brew install)
	;;
	pkg )
		upgrade=(pkg upgrade)
		install=(pkg install)
		(( yes )) && { upgrade+=(-y); install+=(-y) }
	;;
	esac

	if (( ${#f_upgrade} )); then
		$run ${elevate} ${upgrade} || return 1
		# apt-get and zypper only refreshed the lists; upgrade as well
		case $manager in
		apt-get ) $run ${elevate} apt-get upgrade ${${yes:#0}:+-y} || return 1 ;;
		zypper )  $run ${elevate} zypper ${${yes:#0}:+--non-interactive} update || return 1 ;;
		brew )    $run brew upgrade || return 1 ;;
		esac
	fi
	$run ${elevate} ${install} ${missing}
}
