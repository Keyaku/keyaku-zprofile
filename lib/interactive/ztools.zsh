# ============================================================================
# Various useful ZSH tools
# ============================================================================

# A global sourcing function
function zsource {
	emulate -L zsh
	setopt extendedglob

	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...] [NAME...]"
		"Extension to shell built-in command 'source'."
		""
		"\t[-h|--help]          : Print this help message"
		"\t[-v] / [-q]          : Increase / Decrease verbosity"
		"\t[-a|--all]           : Reload everything (except plugins)"
		"\t[-L|--libraries]     : Reload all files under \$ZDOTDIR/lib/"
		"\t[-l|--login]         : Reload zstages/profile/ and zstages/login/"
		"\t[-i|--interactive]   : Reload zstages/rc/"
		"\t[-f|--functions] [NAME...] : Reload all or named functions under \$ZSH_CUSTOM/functions/"
		"\t[-e|--extensions] [NAME...] : Reload all or named extensions under \$ZDOTDIR/extensions/"
		"\t[-p|--plugin] NAME... : Reload named plugin(s). Can be combined with -a"
	)

	# -------------------------------------------------------------------------
	# Argument parsing
	# -------------------------------------------------------------------------
	local -i f_help=0 f_all=0 f_lib=0 f_login=0 f_interactive=0
	local -i f_func=0 f_ext=0 f_plugin=0
	local -i verbosity=0
	local -A flag_names=([f]="" [e]="" [p]="")
	local current_flag=""

	local -a _args=("$@")
	local -a _expanded=()

	# Expand aggregated flags (e.g. -Lli into -L -l -i)
	for arg in $_args; do
		if [[ "$arg" == -[^-]?* ]]; then
			local char
			for char in ${(s::)arg#-}; do
				_expanded+=("-$char")
			done
		else
			_expanded+=("$arg")
		fi
	done

	for arg in $_expanded; do
		case "$arg" in
		-h|--help)        f_help=1;        current_flag="" ;;
		-a|--all)         f_all=1;         current_flag="" ;;
		-L|--libraries)   f_lib=1;         current_flag="" ;;
		-l|--login)       f_login=1;       current_flag="" ;;
		-i|--interactive) f_interactive=1; current_flag="" ;;
		-f|--functions)   f_func=1;        current_flag="f" ;;
		-e|--extensions)  f_ext=1;         current_flag="e" ;;
		-p|--plugin)      f_plugin=1;      current_flag="p" ;;
		-v)               (( verbosity++ )); current_flag="" ;;
		-q)               (( verbosity-- )); current_flag="" ;;
		-*)               print_fn -e "Unknown option: $arg"; return 1 ;;
		*)
			if [[ -n "$current_flag" ]]; then
				flag_names[$current_flag]+="${flag_names[$current_flag]:+ }$arg"
			else
				print_fn -e "Unexpected argument: '$arg'"
				return 1
			fi
		;;
		esac
	done

	# -------------------------------------------------------------------------
	# Check arguments
	# -------------------------------------------------------------------------
	# Help
	if (( f_help )); then
		>&2 print -l $usage
		return 0

	# Check something was requested
	elif (( ! f_all && ! f_lib && ! f_login && ! f_interactive && ! f_func && ! f_ext && ! f_plugin )); then
		print_fn -e "not enough arguments"
		return 1
	fi

	# Expand --all
	if (( f_all )); then
		f_lib=1; f_login=1; f_interactive=1; f_func=1; f_ext=1
	fi

	# Plugin requires names
	if (( f_plugin && ! ${#${(z)flag_names[p]}} )); then
		print_fn -e "[-p|--plugin] requires at least one plugin name"
		return 1
	fi

	# -------------------------------------------------------------------------
	# Collect
	# -------------------------------------------------------------------------
	local -aU _libraries=()
	local -aU _profiles=()
	local -aU _functions=()
	local -aU _extensions=()
	local -aU _plugins=()
	local -aU func_dirs=()  # populated if f_func is set

	# Libraries
	if (( f_lib )); then
		_libraries=("$ZDOTDIR"/lib/**/*.zsh(-.DN))
	fi

	# Login
	if (( f_login )); then
		_profiles+=(
			"$ZDOTDIR"/zstages/profile/*.zsh(-.DN)
			"$ZDOTDIR"/zstages/login/*.zsh(-.DN)
		)
	fi

	# Interactive
	if (( f_interactive )); then
		_profiles+=("$ZDOTDIR"/zstages/rc/*.zsh(-.DN))
	fi

	# Functions
	if (( f_func )); then
		func_dirs=("$ZSH_CUSTOM"/functions/**/(-/FDN:a))
		local -a func_names=(${(z)flag_names[f]})
		if (( ${#func_names} )); then
			# Filter out any names starting with '.'
			func_names=(${func_names:#.*})
			(( ${#func_names} )) && _functions=("$ZSH_CUSTOM"/functions/**/(${(j:|:)~func_names})(-.DN:t))
		else
			_functions=(${^func_dirs}/[^.]*(-.DN:t))
		fi
	fi

	# Extensions
	if (( f_ext )); then
		local -a ext_names=(${(z)flag_names[e]})
		if (( ${#ext_names} )); then
			_extensions=("$ZDOTDIR"/extensions/(${(j:|:)~ext_names})/*.(env|plugin).zsh(-.N))
		else
			_extensions=("$ZDOTDIR"/extensions/(*~example)/*.(env|plugin).zsh(-.N))
		fi
	fi

	# Plugins
	if (( f_plugin )); then
		local -a plugin_paths=("$ZSH_CUSTOM/plugins" "$ZSH/plugins")
		local -a plugin_names=(${(z)flag_names[p]})
		local p name
		for name in $plugin_names; do
			for p in $plugin_paths; do
				if [[ -f "$p/$name/$name.plugin.zsh" ]]; then
					_plugins+=("$p/$name/$name.plugin.zsh")
					break
				fi
			done
		done
	fi

	# Nothing found
	local -i total=$(( ${#_libraries} + ${#_profiles} + ${#_functions} + ${#_extensions} + ${#_plugins} ))
	if (( ! total )); then
		(( verbosity >= 1 )) && print_fn -nw "No valid files found"
		return 1
	fi

	# -------------------------------------------------------------------------
	# Verbosity output
	# -------------------------------------------------------------------------
	if (( verbosity >= 2 )); then
		local -a _all_sources=($_libraries $_profiles $_extensions $_plugins)
		(( ${#_all_sources} )) && printf "%s\n" "Files to source:" ${_all_sources//"$ZDOTDIR"/\$ZDOTDIR}
		(( ${#_functions} )) && printf "%s\n" "Functions to load:" $_functions
	fi

	# -------------------------------------------------------------------------
	# Load
	# -------------------------------------------------------------------------
	_source_guard() {
		local f
		local -i retval=0
		for f; do
			source "$f"
			case $? in
			127 ) print_fn -e "error sourcing '${f//$ZDOTDIR/\$ZDOTDIR}'"
			;&
			126 )
				return 1
			;;
			esac
		done
	}

	# Libraries & Profiles
	_source_guard $_libraries $_profiles

	# Functions
	if (( ${#_functions} )); then
		local -aU func_set=(${fpath:*func_dirs})
		if (( ${#func_dirs} != ${#func_set} )); then
			local -i fc_idx=${fpath[(i)$ZSH_CUSTOM/functions]}
			(( ${#fpath} < fc_idx )) && fc_idx=0
			fpath[${fc_idx}+1,0]=(${func_dirs:|func_set})
		fi
		local fn
		for fn in $_functions; do
			(( ${+functions[$fn]} )) && unfunction "$fn"
		done
		autoload -Uz $_functions
	fi

	# Extensions & Plugins
	_source_guard $_extensions $_plugins

	# -------------------------------------------------------------------------
	# Output
	# -------------------------------------------------------------------------
	if (( verbosity >= 1 )); then
		local -i loaded=$(( ${#_libraries} + ${#_profiles} + ${#_functions} + ${#_extensions} + ${#_plugins} ))
		print_fn -ni "$loaded file(s) loaded"
		if (( verbosity > 1 )); then
			(( ${#_libraries} )) && print_fn -ni "Libraries: ${#_libraries}"
			(( ${#_profiles} )) && print_fn -ni "Profiles: ${#_profiles}"
			(( ${#_functions} )) && print_fn -ni "Functions: ${#_functions}"
			(( ${#_extensions} )) && print_fn -ni "Extensions: ${#_extensions}"
			(( ${#_plugins} )) && print_fn -ni "Plugins: ${#_plugins}"
		fi
	fi

	(( ${+functions[_source_guard]} )) && unfunction _source_guard
	return 0
}

# ============================================================================
# Startup benchmarking
# ============================================================================
# Median of a list of float samples (args). Echoes 0 on empty input.
_zbench_median() {
	local LC_ALL=C
	local -a vals=("${(@f)$(print -l -- "$@" | sort -g)}")
	local -i n=${#vals}
	(( n )) || { print 0; return; }
	if (( n & 1 )); then
		print -- ${vals[(n+1)/2]}
	else
		print -- $(( (vals[n/2] + vals[n/2+1]) / 2.0 ))
	fi
}

# Source-time profile: run `zsh -<case> -c exit` with ZSH_PROFILE_BENCHMARK set,
# $runs times, and aggregate every "<label> took <t>s" / "[TOTAL] … stage" line by
# median. Prints stage TOTALs, their sum, and the heaviest leaf files.
_zbench_profile() {
	local LC_ALL=C
	local -r case=$1
	local -i runs=$2
	local -A samples
	local -i r
	local line label t

	for (( r = 1; r <= runs; r++ )); do
		while IFS= read -r line; do
			[[ "$line" == (#b)*"took "([0-9.eE+-]##)s* ]] || continue
			t=${match[1]}
			label=${line%% took *}
			samples[$label]+=" $t"
		done < <(ZSH_PROFILE_BENCHMARK=1 zsh -${case} -c exit 2>&1)
	done

	(( ${#samples} )) || { print_fn -w "no profile samples for -$case"; return 1; }

	# Stage TOTALs + their sum
	local key
	local -F sum=0 med
	local -a total_lines=() leaf_lines=()
	for key in "${(@k)samples}"; do
		med=$(_zbench_median ${(z)samples[$key]})
		if [[ "$key" == *'[TOTAL]'* ]]; then
			total_lines+=("$(printf '%8.2f  %s' $((med * 1000)) "$key")")
			sum+=$med
		else
			leaf_lines+=("$(printf '%8.2f\t%s' $((med * 1000)) "$key")")
		fi
	done

	print -- "── -$case  (median of $runs runs) ──"
	print -l -- ${(On)total_lines}
	printf '%8.2f  %s\n' $((sum * 1000)) '[SUM of stage TOTALs]'
	print -- "  heaviest leaves (ms):"
	print -l -- ${${(On)leaf_lines}[1,12]} | sed 's/^/  /'
	print --
}

# Wall-clock: end-to-end startup time as actually felt. Uses hyperfine when
# present (best); else a pure-zsh mean over $runs spawns.
_zbench_wall() {
	local LC_ALL=C
	local -i runs=$1
	shift
	local -a cases=("$@")
	local c
	if (( ${+commands[hyperfine]} )); then
		local -a hf=()
		for c in $cases; do hf+=(-n "zsh -$c" "zsh -$c -c exit"); done
		hyperfine -N --warmup 5 --min-runs $(( runs < 20 ? 20 : runs )) $hf
	else
		print_fn -ni "hyperfine not found — pure-zsh mean fallback"
		local -F t0 t1 acc
		local -i i
		for c in $cases; do
			acc=0
			for (( i = 1; i <= runs; i++ )); do
				t0=$EPOCHREALTIME; zsh -$c -c exit &>/dev/null; t1=$EPOCHREALTIME
				acc+=$(( t1 - t0 ))
			done
			printf '  -%-3s mean %7.2fms  (%d runs)\n' "$c" $(( acc / runs * 1000 )) $runs
		done
	fi
}

# Benchmark this zsh environment's startup.
function zbench {
	emulate -L zsh
	setopt extendedglob
	zmodload zsh/datetime

	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...] [CASE...]"
		"Benchmark zsh startup. CASE is one or more of: l i li  (default: li)."
		""
		"\t[-h|--help]     : Print this help message"
		"\t[-n N]          : Runs per profile case (default 10)"
		"\t[-w|--wall]     : Wall-clock only (hyperfine end-to-end)"
		"\t[-p|--profile]  : Source-time profile only (ZSH_PROFILE_BENCHMARK)"
		"\t[-z|--zwc]      : A/B compare with vs without *.zwc (toggles & restores)"
		""
		"With neither -w nor -p, runs both."
	)

	local f_help f_wall f_profile f_zwc
	local -a n_runs_opt
	local -i n_runs=10
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		{w,-wall}=f_wall \
		{p,-profile}=f_profile \
		{z,-zwc}=f_zwc \
		n:=n_runs_opt \
		|| return 1
	[[ -n "$n_runs_opt" ]] && n_runs=${n_runs_opt[2]}

	if [[ -n "$f_help" ]]; then >&2 print -l $usage; return 0; fi

	# Remaining args = cases; validate.
	local -a cases=("${@:-li}")
	local c
	for c in $cases; do
		[[ "$c" == (l|i|li) ]] || { print_fn -e "invalid case '$c' (use l, i, li)"; return 1; }
	done

	# Default: do both wall and profile.
	local -i do_wall=0 do_profile=0
	[[ -n "$f_wall" ]] && do_wall=1
	[[ -n "$f_profile" ]] && do_profile=1
	(( do_wall || do_profile )) || { do_wall=1; do_profile=1; }

	# -z runs the whole suite twice (no-zwc, then zwc) and restores original state.
	if [[ -n "$f_zwc" ]]; then
		local -i had_zwc=0
		[[ -n "$ZDOTDIR"/lib/**/*.zwc(#qN) ]] && had_zwc=1

		print_fn -i "A/B: cleaning *.zwc …"
		zupdate -C -q >/dev/null
		print_fn -ni "═══ WITHOUT zwc ═══"
		(( do_wall ))    && _zbench_wall $n_runs $cases
		(( do_profile )) && for c in $cases; do _zbench_profile $c $n_runs; done

		print_fn -i "A/B: recompiling *.zwc …"
		zupdate -c -q >/dev/null
		print_fn -ni "═══ WITH zwc ═══"
		(( do_wall ))    && _zbench_wall $n_runs $cases
		(( do_profile )) && for c in $cases; do _zbench_profile $c $n_runs; done

		# Restore original state.
		(( had_zwc )) || { print_fn -i "A/B: restoring (no zwc) …"; zupdate -C -q >/dev/null; }
		return 0
	fi

	(( do_wall ))    && { print_fn -ni "Wall-clock"; _zbench_wall $n_runs $cases; }
	(( do_profile )) && {
		print_fn -ni "Source-time profile"
		for c in $cases; do _zbench_profile $c $n_runs; done
	}
	return 0
}

# zcompile helper
function _zcompile_file {
	local f="$1"
	local -i verbosity="${2:-0}"
	local filepath="${${f:h}//$ZDOTDIR\/**\/plugins\/}"

	# If checking for test files, leave early
	[[ "$filepath" == */test* ]] && return

	(( $verbosity > 2 )) && print_fn -nd "Checking $filepath/${f:t}..."
	if [[ ! -f "${f}.zwc" || "$f" -nt "${f}.zwc" ]]; then
		(( $verbosity > 1 )) && print_fn -ni "Compiling $filepath/${f:t}..."
		zcompile "$f"
	fi
}

# Check for zprofile git repo changes
function zupdate {
	if [[ -d "${ZDOTDIR}/.git" ]]; then
		(( ${+commands[git]} )) || return 1
	else
		echo "No git repo found in ZDOTDIR (${ZDOTDIR}). This function does nothing."
		return 1
	fi

	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...]"
		"\t[-h|--help] : Print this help message"
		"\t[-v] / [-q] : Increase / Decrease verbosity"
		"\t[-a|--all]  : Update all steps. Overrides options -r, -s, -c"
		"\t[-r|--repo] : Update repo"
		"\t[-s|--submodules] : Update submodules"
		"\t[-c|--compile] : Compile .zsh in lib/ and plugins/"
		"\t[-C|--clean] : Clean .zwc files from lib/ and plugins/"
	)

	## Setup parseopts
	local f_help f_verbosity
	local -aU f_steps
	zparseopts -D -F -K -- \
		{h,-help}=f_help \
		v+=f_verbosity q+=f_verbosity \
		{a,-all}=f_steps \
		{r,-repo}=f_steps \
		{s,-submodules}=f_steps \
		{c,-compile}=f_steps \
		{C,-clean}=f_steps \
		|| return 1

	## Help/usage message
	if [[ "$f_help" ]]; then
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	### Arg parsing
	# Verbosity
	local -i verbosity=1 # defaults to some verbosity
	f_verbosity="${(j::)f_verbosity//-}"
	(( verbosity += (${#f_verbosity//q} - ${#${f_verbosity//v}}) ))

	# Steps
	if [[ -z "$f_steps" ]] || (( ${f_steps[(I)(-a|--all)]} ));	then
		f_steps=(-r -s -c)
	fi

	# Getting repo info
	local repo_name
	while IFS=$'=\t ' read -r key val; do
		if [[ "$key" == "url" ]]; then
			repo_name="${${val:t}%.git}"
			break
		fi
	done < "${ZDOTDIR}/.git/config"

	if (( ${f_steps[(I)(-r|--repo)]} )); then
		# Update main repo
		(( $verbosity )) && >&2 printf "Checking for updates..."
		git -C "${ZDOTDIR}" fetch -q || {
			print_fn -e "Problem while executing git fetch"
			return 1
		}
		local -a refs=("${(@f)$(git -C "${ZDOTDIR}" rev-parse @ @{u})}")
		local LOCAL="${refs[1]}"
		local REMOTE="${refs[2]}"
		local BASE=$(git -C "${ZDOTDIR}" merge-base @ @{u})

		(( $verbosity )) && >&2 printf '\r\033[0K%s: ' "${repo_name}"
		if [[ $LOCAL == $REMOTE ]]; then
			(( $verbosity )) && print_fn -ns "Up-to-date"
		elif [[ $LOCAL == $BASE ]]; then
			(( $verbosity )) && print_fn -ni "Updating..."
			git -C "${ZDOTDIR}" pull ${f_verbosity:+-${f_verbosity}} || return 1
		elif [[ $REMOTE == $BASE ]]; then
			(( $verbosity )) && print_fn -ne "There are unpushed changes"
			return 2
		else
			(( $verbosity )) && print_fn -ne "Current branch has diverged from remote"
			return 3
		fi
	fi

	# Get directories with plugins/
	local -a plugin_dirs=("$ZSH_CUSTOM")
	[[ -n "$ZSH" ]] && plugin_dirs+=("$ZSH")

	# Clean up .zwc files
	if (( ${f_steps[(I)(-C|--clean)]} )); then
		(( $verbosity )) && print "Cleaning up *.zwc files in lib/ and plugins..."
		rm -f "${ZDOTDIR}"/{extensions,lib}/**/*.zwc(.N) ${^plugin_dirs}/plugins/*/**/*.zwc(.N)
	fi

	# (Re)compile libraries and plugins
	if (( ${f_steps[(I)(-c|--compile)]} )); then
		(( $verbosity )) && print "Recompiling libraries and plugins..."
		local f
		for f in "${ZDOTDIR}"/lib/**/*.zsh(on); do
			_zcompile_file "$f" $verbosity &!
		done

		# Compile plugins
		local -a p_results=()
		for f in ${plugins}; do
			p_results=(${^plugin_dirs}/plugins/$f(N))
			# If results were found, pick the first one
			if (( ${#p_results} )); then
				local plugin_root="${p_results[1]}"
				for zwc_f in "$plugin_root"/**/*.zsh(.N); do
					_zcompile_file "$zwc_f" $verbosity &!
				done
			fi
		done

		# Wait for all background jobs to finish
		wait

		(( $verbosity )) && print "Reloading freshly recompiled libraries..."
		zsource -L
	fi

	# Update submodules
	if (( ${f_steps[(I)(-s|--submodules)]} )); then
		(( $verbosity )) && printf '%s' "Initializing/updating submodules..."

		# Self-heal devices left behind by the legacy custom/ -> vendor/ submodule
		# move: a worktree `.git` may point to a gitdir under .git/modules/<new>
		# while the real gitdir still sits at .git/modules/custom/<old>, leaving a
		# dangling handle ("could not get a repository handle"). Drop the broken
		# worktree (re-cloned by the update below) and prune stale config sections
		# for submodules no longer in .gitmodules. Cheap: only on `--submodules`.
		local sm_key sm_path sm_name
		git -C "${ZDOTDIR}" config -f "${ZDOTDIR}/.gitmodules" --get-regexp '^submodule\..*\.path$' | \
			while read -r sm_key sm_path; do
				[[ -e "${ZDOTDIR}/${sm_path}/.git" ]] || continue
				git -C "${ZDOTDIR}/${sm_path}" rev-parse --git-dir &>/dev/null && continue
				print_fn -w "submodule '${sm_path}' has a dangling gitdir — re-cloning"
				rm -rf "${ZDOTDIR:?}/${sm_path}"
			done
		# Prune config sections for submodules absent from .gitmodules (e.g. old
		# custom/* duplicates, removed plugins) so they don't shadow the update.
		git -C "${ZDOTDIR}" config --get-regexp '^submodule\..*\.url$' | \
			while read -r sm_key _; do
				sm_name="${sm_key#submodule.}"
				sm_name="${sm_name%.url}"
				git -C "${ZDOTDIR}" config -f "${ZDOTDIR}/.gitmodules" \
					--get "submodule.${sm_name}.path" &>/dev/null && continue
				git -C "${ZDOTDIR}" config --remove-section "submodule.${sm_name}" 2>/dev/null
			done

		git -C "${ZDOTDIR}" submodule -q update --init --recursive --remote --jobs=$(nproc)

		# Propagate `ignore` from .gitmodules into .git/config — git status/p10k
		# read `submodule.<name>.ignore` from config only, not .gitmodules, so
		# `ignore = all` (keep submodules always-latest without committing the
		# pointer bumps) has no effect until mirrored here. `submodule sync`
		# carries url/branch but NOT ignore, hence this loop.
		local sm_ignore
		git -C "${ZDOTDIR}" config -f "${ZDOTDIR}/.gitmodules" --get-regexp '^submodule\..*\.ignore$' | \
			while read -r sm_name sm_ignore; do
				sm_name="${sm_name#submodule.}"
				sm_name="${sm_name%.ignore}"
				git -C "${ZDOTDIR}" config "submodule.${sm_name}.ignore" "$sm_ignore"
			done

		(( $verbosity )) && printf ' %s\n' "Done."
	fi

	# Warn on completion drift between lib/ functions and completions/_<name>.
	# Silent on success; non-zero exit is informational, not fatal.
	if [[ -x "${ZDOTDIR}/conf/check-completions.zsh" ]]; then
		"${ZDOTDIR}/conf/check-completions.zsh" -q || \
			print_fn -w "completion drift detected — see above; run conf/check-completions.zsh for details"
	fi
}
