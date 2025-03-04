function file_contents_in {
	# diff ignoring all types of whitespaces and getting only the differences
	diff -BNPZbqrw --changed-group-format='%<' --unchanged-group-format='' $@ &>/dev/null
}
