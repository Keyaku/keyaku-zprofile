##############################################
### ZSH helpers
##############################################

# Assign a value to a named variable
function assign {
	(( 2 == $# )) || return 1
	if [[ ! -v "$1" ]]; then
		print_fn -e "Argument is not a variable: '$1'"
		return 1
	elif is_array "$1"; then
		print_fn -e "This function does not work with arrays!"
		return 1
	fi

	# Magic ZSH expansion
	: ${(P)1::=${2}}
}

##############################################
### Composite variable control
##############################################

# Checks if a defined variable $1 with colon-delimited values contains a given value $2
function hasvar {
	# If parent function is not addvar or rmvar, impose argument restrictions
	if ! [[ "${funcstack[3]}" == (add|rm)var ]]; then
		(( 2 == $# )) || return 1
	fi

	# $1: name of the variable to check
	# $2: value to check
	local varvalue="${(P)1}"
	local val="$2"

	[[ ":${varvalue}:" == *":${val}:"* ]]
}

# Adds value(s) in defined variable $1 if not in there. If no adding took place, return false
function addvar {
	# $1 : name of variable OR prepend value
	# $2 : (if prepend value set) name of variable
	# $2+: vars to add

	local -i prepend=0
	[[ "$1" == (0|1) ]] && { prepend=$1; shift; }

	local -i retval=1
	local varname="$1"
	shift

	local arg
	for arg; do
		## If given var exists & it's not set in variable
		if ! hasvar $varname "$arg"; then
			retval=0
			if (( $prepend )); then
				assign ${varname} "$arg:${(P)varname}"
			else
				assign ${varname} "${(P)varname}:$arg"
			fi
		fi
	done

	return $retval
}

# Removes value(s) from defined variable 1 if in there. If no removal took place, return false
function rmvar {
	# $1+: vars to remove
	(( 0 < $# )) || return 1

	local -i retval=1
	local varname="$1"
	shift

	# Remove each item if existing in variable
	local arg
	for arg; do
		if hasvar "$varname" "$arg"; then
			local -a parts=("${(s[:])${(P)varname}}")
			parts=("${(@)parts:#$arg}")
			assign ${varname} "${(j[:])parts}"
			retval=0
		fi
	done

	return $retval
}

# Checks if all given environment variables are set or not empty
function check_envvars {
	# $@: variable names
	local -a missing_vars
	for arg; do
		[[ -v "$arg" && -n "${(P)arg}" ]] || missing_vars+=("$arg")
	done

	if (( ${#missing_vars} )); then
		print_fn -e "Environment variable(s) not set:" "${(j:, :)@}"
		return 1
	fi
}


##############################################
### Environment control
##############################################
### PATH variable environment control

# Checks if argument exists in $path
function haspath {
	(( 0 < ${path[(I)(${(j:|:)@})]} ))
}

# Adds argument(s) to $path if not set and if they're existing directories. Returns false if no path was set
function addpath {
	local -i mode=0  # 0: append; 1: prepend
	local -a append_paths=()
	local -a prepend_paths=()
	local arg

	# Parse arguments
	for arg; do
		case "$arg" in
		-a|--append)  mode=0 ;;
		-p|--prepend) mode=1 ;;
		*)
			# Check if path exists and is not already in $path
			if [[ -d "$arg" ]] && ! haspath "$arg"; then
				if (( ! $mode )); then
					append_paths+=("$arg")
				else
					prepend_paths+=("$arg")
				fi
			fi
		;;
		esac
	done

	# Add paths
	(( ${#prepend_paths} )) && path=(${prepend_paths} ${path})
	(( ${#append_paths} ))  && path+=(${append_paths})

	# Return success if any paths were added
	(( 0 < ${#prepend_paths} + ${#append_paths} ))
}

# Remove argument from $path. Returns false if no value was removed
function rmpath {
	local -a removal=("$@")
	local -a tmp=(${path})

	# Use ZSH array filtering with parameter expansion
	path=(${path:|removal})

	# return true if at least one argument removed
	(( 0 != ($#tmp - $#path) ))
}
