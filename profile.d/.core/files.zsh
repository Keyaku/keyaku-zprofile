function file_contents_in {
	check_argc 2 2 $#
	local file1="${1:a}"
	local file2="${2:a}"
	local differences="$(diff -r "$file1" "$file2" | sed -En '/^</p')"
	[[ -z "$differences" ]]
}
