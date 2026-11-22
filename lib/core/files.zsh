# ============================================================================
# File operations helpers
# ============================================================================

# Checks if a file's contents can be found in another file
function file_contents_in {
	local -r usage=(
		"Usage: ${funcstack[1]} [-q] source target"
		"\t[-q|--quiet] : Suppress output"
		"\tsource       : Source file or directory"
		"\ttarget       : Target file or directory"
	)

	local f_quiet
	zparseopts -D -F -K -- \
		{q,-quiet}=f_quiet \
		|| { >&2 print -l $usage; return 1; }

	check_argc $# 2 2 || { >&2 print -l $usage; return 1; }

	local source="$1" target="$2"

	# Validate that source and target are of the same type
	[[ -f "$source" && -f "$target" ]] || \
	[[ -d "$source" && -d "$target" ]] || {
		print_fn -e "Source and target must both be files or both be directories."
		return 1
	}

	# Lines compare with comments and all whitespace removed, as plain strings
	# (no regex), so `Key  value` and `Key value # note` match each other.
	_file_contents_in_file() {
		local source="$1" target="$2"
		local -i missing=0
		local line
		local -A have=()

		if [[ -r "$target" ]]; then
			for line in "${(@f)$(<$target)}"; do
				line="${${line%%#*}//[[:space:]]}"
				[[ -n "$line" ]] && have[$line]=1
			done
		fi

		while IFS= read -r line || [[ -n "$line" ]]; do
			line="${${line%%#*}//[[:space:]]}"
			[[ -z "$line" ]] && continue
			if (( ! ${+have[$line]} )); then
				(( missing++ ))
				[[ -z "$f_quiet" ]] && print -r -- "$line"
			fi
		done < "$source"

		(( missing == 0 ))
	}

	_file_contents_in_dir() {
		local source="$1" target="$2"
		local -i missing=0
		local file relative

		for file in "$source"/**/*(.DN); do
			relative="${file#$source/}"
			if [[ ! -f "$target/$relative" ]]; then
				(( missing++ ))
				[[ -z "$f_quiet" ]] && print_fn -w "Missing file: $relative"
			elif ! _file_contents_in_file "$file" "$target/$relative"; then
				(( missing++ ))
			fi
		done

		(( missing == 0 ))
	}

	local -i rc
	if [[ -f "$source" ]]; then
		_file_contents_in_file "$source" "$target"
	else
		_file_contents_in_dir "$source" "$target"
	fi
	rc=$?

	# Keep the result: unfunction's own status used to replace it, so this
	# always reported success
	unfunction _file_contents_in_file _file_contents_in_dir
	return rc
}

# For truly minimal overhead, fastcmp is a wrapper
# around the builtin `sysread` to read file contents directly
function fastcmp {
	local content1 content2

	# Read files directly into memory using ZSH builtins
	# Limit file read size to 1MB. Anything above will be truncated
	{ sysread -s 1048576 content1 < "$1"; } 2>/dev/null || return 2
	{ sysread -s 1048576 content2 < "$2"; } 2>/dev/null || return 2

	# Direct string comparison
	[[ "$content1" == "$content2" ]]
}

# Prints a file's encoding
alias file_encoding='file -bi'
