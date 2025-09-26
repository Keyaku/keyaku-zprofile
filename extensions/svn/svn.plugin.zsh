(( ${+commands[svn]} )) || return

# Load available plugin from ohmyzsh
[[ -f "$ZSH/plugins/${0:h:t}/${0:t}" ]] && source "$ZSH/plugins/${0:h:t}/${0:t}"

### Personal configuration

alias svn='svn --config-dir ${XDG_CONFIG_HOME}/subversion'
export SVN_STASH="$XDG_CONFIG_HOME/subversion/stash"
[[ -d "$SVN_STASH" ]] || mkdir -p "$SVN_STASH"

function svn_root {
	svn info --show-item wc-root $@
}

function svn_path {
	svn info --show-item relative-url $@ | sed 's/^\^//'
}

function svn_ls_stash {
	# Arg checking
	local BOOL_all=false
	local BOOL_pretty=false

	while (( $# )); do
		case $1 in
		-a | --all ) BOOL_all=true ;;
		-p | --pretty-print ) BOOL_pretty=true ;;
		* ) echo "Invalid argument: \"$1\"" ;;
		esac
		shift
	done

	#
	local stashes=()
	local projname
	local DIR_stash

	if [[ $BOOL_all = true ]]; then
		local stashes=()
		for dir in $SVN_STASH/*; do
			stashes=($(ls -tc $dir/*.patch | xargs -n 1 basename))
			printf "$(basename $dir):"
			echo ${stashes[@]/#/\\nL--- }
		done
	else
		# Assume current work directory

		# Get project name and format patch filename
		projname="$(basename $(svn info | grep 'Repository Root' | cut -d' ' -f3))"
		DIR_stash="$SVN_STASH/$projname"

		# If stash directory doesn't even exist
		if [[ ! -d "$DIR_stash" ]]; then
			echo "No stashes found for $projname"
			return 0
		fi

		stashes=($(ls -tc $DIR_stash/*.patch | xargs -n 1 basename))
		printf "$projname:"
		[[ $BOOL_pretty = true ]] && echo ${stashes[@]/#/\\nL--- } || echo "\n${stashes[*]}"
	fi
}

function svn_stash {
	# Check if we're in an svn repo
	[[ $(svn info >/dev/null; echo $?) -eq 0 ]] || return 1

	# Check if there are changes to be done
	if [[ -z "$(svn diff)" ]]; then
		echo "There are no changes to be stashed"
		return 0
	fi

	# Create stash directory if missing, and get project name
	local projname="$(basename $(svn info | grep 'Repository Root' | cut -d' ' -f3))"
	local DIR_stash="$SVN_STASH/$projname"
	[[ ! -d "$DIR_stash" ]] && mkdir -p "$DIR_stash"

	# Format patch filename
	local filename="stash-$(date +%g%m%d-%H%M%S)"
	local -i loop=0
	while (( ! $loop )); do
		ask -k -q "Name for stash?" -d "$filename.patch"

		if [[ -e "$DIR_stash/$REPLY.patch" ]]; then
			echo "$REPLY already exists. Pick another name."
		else
			loop=1
			filename="$REPLY"
		fi
	done

	local stash_patch="$DIR_stash/$filename.patch"
	# Stash changes, then revert changes
	svn diff > "$stash_patch"
	if [[ $? -eq 0 ]]; then
		svn revert -R .
		echo "Changes were stashed to $stash_patch"
	fi
}

function svn_unstash {
	# Check if we're in an svn repo
	svn info >/dev/null || return 1

	# Get project name and format patch filename
	local projname="$(basename $(svn info | grep 'Repository Root' | cut -d' ' -f3))"
	local DIR_stash="$SVN_STASH/$projname"

	# If stash directory doesn't even exist
	if [[ ! -d "$DIR_stash" ]]; then
		echo "No stashes found for $projname"
		return 1
	fi

	# Args parsing
	local BOOL_keep=false
	local stash_patch
	local to_unstash=()
	while (( $# )); do
		case $1 in
		-k | --keep ) BOOL_keep=true ;;
		* )
			# Check if value is a patch file stashed
			if [[ -f "$DIR_stash/$(basename "$1").patch" ]]; then
				to_unstash+=("$1")
			else
				echo "Invalid argument: \"$1\""
			fi
		;;
		esac
		shift
	done

	if (( 0 == ${#to_unstash[@]} )); then
		# Fetch list of stashes, sorted by creation/modification date
		local stash_list=($(ls -tc $DIR_stash/*.patch | xargs -n 1 basename | sed 's/.patch$//'))

		if (( 1 < ${#stash_list[@]} )); then
			# Let user pick which stash to apply
			echo "Which one would you like to apply?"
			for ((idx=1; idx <= ${#stash_list[@]}; idx++)); do
				echo "$idx. ${stash_list[$idx]}"
			done
			ask -k -q "> "
			idx=$REPLY

			if is_int $idx && [ $idx -gt 0 -a $idx -le ${#stash_list[@]} ]; then
				to_unstash+=("${stash_list[$idx]}")
			else
				echo "Invalid value. Try again"
				return 1
			fi
		else
			to_unstash+=("${stash_list[1]}")
		fi
	fi

	for patch_file in ${to_unstash[@]}; do
		local stash_patch="$DIR_stash/$patch_file.patch"

		echo "Applying stash \"$patch_file\"..."
		svn patch "$stash_patch"
		if [[ $? -eq 0 ]]; then
			printf "Stash successful; "
			if [[ $BOOL_keep = true ]]; then
				echo "patch file kept."
			else
				rm -f "$stash_patch"
				echo "patch file deleted."
			fi
		fi
	done
}

# function svn_revert {
# 	svn merge -c -$1 .
# }

function svn_ignore_unversioned {
	local FILE_ignore="ignoring.txt"
	svn status | grep "^\?" | awk "{print \$2}" > $FILE_ignore
	echo "File '$FILE_ignore' created. After making your changes, apply the ignore with the following command:"
	echo "svn propset svn:ignore -F ignoring.txt ."
}

function svn_changes {
	local retval=0 args=()
	local BOOL_diff=false
	local BOOL_multi=false
	local svn_dir svn_list=()
	local gexp="^\s*(M\|?)"

	local opt OPTARG OPTIND=1
	while getopts ":admE:" opt; do
		case "$opt" in
		a) args+=("--all") ;;
		d) args+=("--diff") ;;
		m) args+=("--multi") ;;
		E) args+=("--regex" "$OPTARG") ;;
		\?) echo "Unknown option: '$opt'"
		esac
	done
	set -- ${args[@]}

	while (( $# )); do
		case $1 in
		--all ) gexp="" ;;
		--diff ) BOOL_diff=true ;;
		--multi ) BOOL_multi=true ;;
		--regex )
			gexp="$2"
			shift
		;;
		esac
		shift
	done

	# If multiproject option was given, search current directory for svn repos instead of treating current directoy as a repo
	if [[ $BOOL_multi == false ]]; then
		svn_list=(.)
	else
		svn_list=($(find . -maxdepth 1 -type d -not -path . | sed 's|^./||g'))
	fi

	echo > changed.txt

	for svn_dir in ${svn_list[@]}; do
		# Check if the given directory is an svn working copy
		# svn status $svn_dir --depth=empty 2>/dev/null || continue
		[[ ! -d "$svn_dir/.svn" ]] && continue
		# TODO: filter directories
		echo "Checking changes for $svn_dir"
		svn status $svn_dir --ignore-externals | grep -E "$gexp" #| awk "{print \$2}"
		svn status $svn_dir --ignore-externals | grep -E "^\s*(M\|?)" | awk "{print \$2}" >> changed.txt
	done

	if [[ $BOOL_diff == true ]]; then
		echo > changed.patch
		while read -r line; do
			[[ -f "$line" ]] && svn diff "$line" >> changed.patch
		done < changed.txt
	fi

	return $retval
}
