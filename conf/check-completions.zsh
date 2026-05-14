#!/usr/bin/env zsh
# Reports drift between lib/ functions and completions/_<name> files.
#
# Exits 0 if in sync, 1 if drift is found, 2 on usage error.
# Used by the pre-commit hook (conf/hooks/pre-commit) and by zupdate.
#
# Usage: check-completions.zsh [-q|--quiet]
#   -q  Suppress success output; still prints drift to stderr.

emulate -L zsh
setopt extended_glob no_unset pipefail typeset_silent

local repo_root="${0:A:h:h}"
local lib_dir="${repo_root}/lib"
local comp_dir="${repo_root}/completions"
local skip_file="${comp_dir}/.skip"

local f_quiet=0
case "${1:-}" in
	-q|--quiet) f_quiet=1 ;;
	'') ;;
	*) >&2 print "Usage: ${0:t} [-q|--quiet]"; exit 2 ;;
esac

[[ -d "$lib_dir"  ]] || { >&2 print "lib/ not found: $lib_dir"; exit 2 }
[[ -d "$comp_dir" ]] || { >&2 print "completions/ not found: $comp_dir"; exit 2 }

# 1. Extract function names from lib/core/ and lib/interactive/ (skip lib/login/ if empty).
#    Matches:  function NAME {  |  function NAME ()  |  NAME () {
local -aU lib_funcs
local file line name=
for file in "$lib_dir"/{core,interactive,login}/*.zsh(N); do
	while IFS= read -r line; do
		# Strip leading whitespace so indented definitions match.
		line="${line##[[:space:]]##}"
		# Only match `function NAME …` form (repo convention for top-level
		# public functions; `name() {` is reserved for nested locals).
		if [[ "$line" == (#b)function[[:space:]]##([[:alnum:]_-]##)* ]]; then
			name="${match[1]}"
			# Skip underscore-prefixed internal helpers.
			[[ "$name" != _* ]] && lib_funcs+=("$name")
		fi
	done < "$file"
done

# 2. Load skip list.
local -aU skip_list
if [[ -f "$skip_file" ]]; then
	while IFS= read -r line; do
		[[ "$line" == \#* ]] && continue
		line="${line//[[:space:]]/}"
		[[ -n "$line" ]] && skip_list+=("$line")
	done < "$skip_file"
fi

# 3. Collect existing completion files.
local -aU comp_funcs
for file in "$comp_dir"/_*(N); do
	# Prefer the #compdef line; fall back to filename minus underscore.
	local first_line=
	IFS= read -r first_line < "$file"
	if [[ "$first_line" == \#compdef[[:space:]]* ]]; then
		comp_funcs+=(${=first_line#\#compdef[[:space:]]})
	else
		comp_funcs+=("${${file:t}#_}")
	fi
done

# 4. Diff.
local -aU missing orphaned
local fn
for fn in $lib_funcs; do
	(( ${skip_list[(I)$fn]} )) && continue
	(( ${comp_funcs[(I)$fn]} )) && continue
	missing+=("$fn")
done
for fn in $comp_funcs; do
	(( ${lib_funcs[(I)$fn]} )) && continue
	(( ${skip_list[(I)$fn]} )) && continue
	orphaned+=("$fn")
done

# 5. Report.
local -i rc=0
if (( ${#missing} )); then
	rc=1
	>&2 print "Missing completions for lib/ functions:"
	>&2 print -l "  ${^missing}"
fi
if (( ${#orphaned} )); then
	rc=1
	>&2 print "Orphaned completions (no matching lib/ function):"
	>&2 print -l "  ${^orphaned}"
fi
if (( rc == 0 )) && (( ! f_quiet )); then
	print "completions in sync (${#lib_funcs} functions, ${#comp_funcs} completions, ${#skip_list} skipped)"
fi
exit $rc
