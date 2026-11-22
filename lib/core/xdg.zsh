### Aliases to get default settings
alias xdg-get-default-browser='xdg-settings get default-web-browser'

### Migrate from one directory to another using envvars
# TODO: Implement missing functionality
function xdg-migrate {
	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...] SRC_PATH DST_PATH"
		"\t-h, --help : Displays this message"
		"\t-d, --dry-run : Do not execute anything; just print"
		"\t-s, --symlink : Also create a symbolic link from SRC_PATH to DST_PATH after migrating"
		"\t-a, --auto : Automatic call (from an extension): only migrate in interactive shells, returning 2 otherwise"
		"\t-e, --env VAR : Like --auto, and when nothing was migrated and DST_PATH doesn't exist yet, unset VAR so the tool keeps its default location"
		"A directory SRC is moved to (or merged into) DST; a file SRC is moved into DST when DST is a directory, else renamed to DST."
		"Every migration of SRC is counted; from the ${XDG_MIGRATE_WARN_AT:-3}rd on, a warning says something keeps recreating it."
	)

	## Setup func opts
	local f_help f_dryrun f_sym f_auto f_env
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{d,-dry-run}=f_dryrun \
		{s,-symlink}=f_sym \
		{a,-auto}=f_auto \
		{e,-env}:=f_env \
		|| return 1

	if [[ -n "$f_help" ]]; then
		>&2 print -l $usage
		return 0
	fi

	## Check positional arguments
	check_argc $# 2 2 || return 1
	local src="$1" dst="$2"
	local env_var="${f_env[-1]}"

	# Automatic calls run from every kind of shell, including the .zshenv stage
	# of scp/rsync/cron ones: only move data where a person can see it happen.
	if [[ -n "$f_auto$env_var" ]] && [[ ! -o interactive ]]; then
		[[ -n "$env_var" && ! -e "$dst" ]] && unset "$env_var"
		return 2
	fi

	[[ -e "$src" ]] || { print_fn -e "'$src': path not found or valid"; return 1; }

	## Parse arguments
	if [[ "$f_dryrun" ]]; then
		f_dryrun="echo"
		print_fn -i "Dry-run mode enabled"
	fi

	local -i retval=0
	## If src is a directory
	if [[ -d "$src" ]]; then
		print_fn -i "Migrating $src to $dst"
		if [[ -d "$dst" ]]; then
			$f_dryrun rsync -Prazq "$src"/ "$dst" && $f_dryrun rm -r "$src"
		else
			[[ -d "${dst:h}" ]] || $f_dryrun mkdir -p "${dst:h}"
			$f_dryrun mv "$src" "$dst"
		fi
		retval=$?
	## If src is a file: into DST when it's a directory, else renamed to DST
	elif [[ -f "$src" ]]; then
		print_fn -i "Moving $src to $dst"
		[[ -d "$dst" || -d "${dst:h}" ]] || $f_dryrun mkdir -p "${dst:h}"
		$f_dryrun mv "$src" "$dst"
		retval=$?
	else
		print_fn -e "Something went wrong; '$src' not a valid file or directory"
		retval=128
	fi

	## If requested, create a symlink from the original path to the migrated destination
	if (( retval == 0 )) && [[ -n "$f_sym" ]]; then
		$f_dryrun ln -s "$dst" "$src"
		retval=$?
	fi

	if (( retval )); then
		[[ -n "$env_var" && ! -e "$dst" ]] && unset "$env_var"
		return $retval
	fi
	[[ -z "$f_dryrun" ]] && _xdg_migrate_count "$src"
	return 0
}

# Counts each migration of SRC under $ZSH_CACHE_HOME/xdg-migrate and warns once
# it recurs: a path that keeps coming back is being recreated by something (an
# app ignoring its XDG variable, a session started before the variable was set)
# and needs a fix at the source rather than another move.
function _xdg_migrate_count {
	local -r src="${1:A}"
	local -r count_dir="${ZSH_CACHE_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh}/xdg-migrate"
	local -r count_file="$count_dir/${src//\//:}"
	local -i count=0
	local first
	[[ -d "$count_dir" ]] || mkdir -p "$count_dir"
	[[ -r "$count_file" ]] && read -r count first < "$count_file"
	(( count++ ))
	[[ -n "$first" ]] || first=$(date +%F)
	print -r -- "$count $first" >| "$count_file"
	if (( count >= ${XDG_MIGRATE_WARN_AT:-3} )); then
		print_fn -w "$src has been migrated $count times since $first: something keeps recreating it. Find what writes there and fix it at the source (reset with: rm '$count_file')"
	fi
}

### Update desktop entries
alias xdg-desktop-update="update-desktop-database $XDG_DATA_HOME/applications"

# Check for dotfiles in HOME
function xdg-home-check {
	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...] FILENAME"
		"\t[-h|--help]"
	)

	## Setup func opts
	local f_help f_simple f_all
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{s,-simple}=f_simple \
		{a,-all}=f_all \
		|| return 1

	## Help/usage message
	if [[ "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	local dotfiles dotcount
	dotfiles=($HOME/.*(:s,$HOME/,,))
	dotcount=${#dotfiles}
	if [[ -z "$f_all" ]]; then
		dotfiles=(${dotfiles:#.local})
		dotcount=${#dotfiles}
	fi

	printf "%s%s\n" "Number of dotfiles: $dotcount" "${f_all:+ (including .local)}"

	if (( $dotcount )); then
		## If simple mode, use printf's array unroll
		if [[ "$f_simple" ]]; then
			printf " - %s\n" "${(@)dotfiles}"
		# Otherwise, print detailed info
		else
			local dotfile
			for dotfile in ${(@)dotfiles}; do
				printf " - \033[1m\033[3m%-10s\033[0m : %s\n" "$dotfile" "$(file -b "$HOME/$dotfile")"
			done
		fi
	fi

}
