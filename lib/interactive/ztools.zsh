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
			(( ${#func_names} )) && _functions=("$ZSH_CUSTOM"/functions/**/(${(j:|:)func_names})(-.DN:t))
		else
			_functions=(${^func_dirs}/[^.]*(-.DN:t))
		fi
	fi

	# Extensions
	if (( f_ext )); then
		local -a ext_names=(${(z)flag_names[e]})
		if (( ${#ext_names} )); then
			_extensions=("$ZDOTDIR"/extensions/(${(j:|:)ext_names})/*.(plugin|ext).zsh(-.N))
		else
			_extensions=("$ZDOTDIR"/extensions/(*~example)/*.(plugin|ext).zsh(-.N))
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
		for f; do
			if ! source "$f" 2>/dev/null && [[ ! -r "$f" ]]; then
				print_fn -e "error sourcing '${f//$ZDOTDIR/\$ZDOTDIR}'"
				return 1
			fi
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

	unfunction _source_guard
	return 0
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
		"\t[-c|--compile] : Compile .zsh in lib/"
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

	### Getting repo info
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

	# Clean up .zwc files
	if (( ${f_steps[(I)(-C|--clean)]} )); then
		(( $verbosity )) && print "Cleaning up *.zwc files in lib/..."
		rm -f ${ZDOTDIR}/lib/**/*.zwc(.N)}
	fi

	# (Re)compile lib/ files
	if (( ${f_steps[(I)(-c|--compile)]} )); then
		(( $verbosity )) && print "Recompiling lib/ files..."
		local f
		for f in "${ZDOTDIR}"/lib/**/*.zsh(on); do
			if [[ ! -f "${f}.zwc" || "$f" -nt "${f}.zwc" ]]; then
				zcompile "$f" &!
			fi
		done
		wait
	fi

	# Update submodules
	if (( ${f_steps[(I)(-s|--submodules)]} )); then
		(( $verbosity )) && printf '%s' "Initializing/updating submodules..."
		git -C "${ZDOTDIR}" submodule -q update --init --recursive --remote --jobs=$(nproc)
		(( $verbosity )) && printf ' %s\n' "Done."
	fi
}

# Benchmarks a given zsh profile
# TODO: Improve this function
function zbenchmark {
	local -r usage=(
		"Usage: ${funcstack[1]} [OPTION...] FILE"
		"Uses zsh module 'zprof' to benchmark zsh profile(s)."
		""
		"\t[-h|--help] : Print this help message"
		"\t[-v] / [-q] : Increase / Decrease verbosity"
		"\t[-l|--login] : Sources file(s) using login shell ('zsh -l')"
		"\t[-i|--interactive] : Sources file(s) using interactive shell ('zsh -i')"
	)

	## Setup parseopts (with no extra arguments)
	local void f_help f_verbosity
	local -aU f_opts
	zparseopts -a void -D -F -K -- \
		{h,-help}=f_help \
		v+=f_verbosity q+=f_verbosity \
		{l,-login}=f_opts \
		{i,-interactive}=f_opts \
		|| return 1

	## Help/usage message
	if (( ! $# )) || [[ "$f_help" ]]; then
		(( ! $# )) && print_fn -e "at least 1 argument required, $# given"
		>&2 print -l $usage
		[[ "$f_help" ]]; return $?
	fi

	### Arg parsing
	# Verbosity
	local -i verbosity=0
	f_verbosity="${(j::)f_verbosity//-}"
	(( verbosity += (${#f_verbosity//q} - ${#${f_verbosity//v}}) ))

	# Aggregate all profiles
	local -ra valid_profiles=(z{sh{,env,rc},profile,log{in,out}})
	local -aU args=(${@:A})
	local -aU _profiles=(${args}(.N)) # Gather only existing files
	local -aU invalid_profiles=(${args:|_profiles})

	# Filter invalid profiles
	local _prof
	for _prof in $_profiles; do
		if [[ ! -f "$_prof" ]] || (( ! ${valid_profiles[(I)${_prof:e}]} )); then
			invalid_profiles+=("$_prof")
			continue
		fi
	done
	_profiles=(${_profiles:|invalid_profiles})

	# Only benchmark if there are any files to benchmark
	if (( ${#_profiles} )); then
		zsh ${f_opts} -c "zmodload zsh/zprof; for _prof in $_profiles; do source \$_prof >/dev/null; done; zprof"
	fi

	# Check if there are invalid files, printing errors accordingly
	if (( ${#invalid_profiles} )); then
		(( 1 <= $verbosity )) && print_fn -e "Invalid file(s) passed. Make sure they exist and are valid zsh files."
		if (( 2 <= $verbosity )); then
			echo "List of invalid files:"
			printf '- %s\n' $invalid_profiles
		fi
	fi

	(( 0 < ${#_profiles} && 0 == ${#invalid_profiles} ))
}
