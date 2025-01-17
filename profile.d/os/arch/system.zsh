if whatami Arch; then

function pacman-pkg-binpath {
	check_argc 1 0 $# || return $?
	while (( $# )); do
		pacman -Ql "$1" | \grep -Eo -m1 '/usr(/.+)?/bin/[^/]+'
		shift
	done
}

fi
