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

	function _file_contents_in_file {
		local source="$1" target="$2"
		local -i missing=0
		local line

		while IFS= read -r line; do
			# Strip inline comments and surrounding whitespace
			line="${${line%%#*}//[[:space:]]}"
			# Skip blank lines
			[[ -z "$line" ]] && continue
			# Check if line exists in target, ignoring whitespace
			if ! grep -qw "$line" "$target" 2>/dev/null; then
				(( missing++ ))
				[[ -z "$f_quiet" ]] && print "$line"
			fi
		done < "$source"

		return $(( missing > 0 ))
	}

	function _file_contents_in_dir {
		local source="$1" target="$2"
		local -i missing=0

		local file
		while IFS= read -r file; do
			local relative="${file#$source/}"
			local target_file="$target/$relative"

			if [[ ! -f "$target_file" ]]; then
				(( missing++ ))
				[[ -z "$f_quiet" ]] && print_fn -w "Missing file: $relative"
				continue
			fi

			if ! _file_contents_in_file "$file" "$target_file"; then
				(( missing++ ))
			fi
		done < <(find "$source" -type f)

		return $(( missing > 0 ))
	}

	if [[ -f "$source" ]]; then
		_file_contents_in_file "$source" "$target"
	else
		_file_contents_in_dir "$source" "$target"
	fi

	unfunction _file_contents_in_file _file_contents_in_dir
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
