# ============================================================================
# First-time initialization check
# ============================================================================
if (( $UID >= 1000 )) && { [[ ! -f "$ZDOTDIR/conf/.first_init" ]] || (( 1 != $(<"$ZDOTDIR/conf/.first_init") )) }; then
	print -u2 "Warning: The ZSH profile was not initialized. Run the following command to ensure everything works as expected:"
	printf "\t%s\n" "zsh "$ZDOTDIR"/conf/first_init.zsh"
fi

# ============================================================================
# Initialize submodules if ohmyzsh is not present or empty
# ============================================================================

if (( ! ${#ZPROFILE_MODULES} )); then
	if [[ ! -s "$ZSH_CACHE_HOME/zprofile_modules" || "$ZPROFILE_REPO/.gitmodules" -nt "$ZSH_CACHE_HOME/zprofile_modules" ]]; then
		# Fetch info from .gitmodules
		while IFS=$'=\t ' read -r key val; do
			if [[ "$key" == "path" ]]; then
				ZPROFILE_MODULES+=("${val}")
			fi
		done < "$ZPROFILE_REPO/.gitmodules"

		# Cache info for following sessions
		print -l "${ZPROFILE_MODULES}" > "$ZSH_CACHE_HOME/zprofile_modules"
	else
		ZPROFILE_MODULES=($(<"$ZSH_CACHE_HOME/zprofile_modules"))
	fi
fi
# Only submodules the user hasn't disabled (see _zsubmodule_enabled)
local -a empty_modules=("$ZDOTDIR"/${^ZPROFILE_MODULES}(N^F))
local empty_module
for empty_module in ${empty_modules}; do
	_zsubmodule_enabled "$empty_module" || empty_modules=(${empty_modules:#$empty_module})
done
unset empty_module
if (( ${#empty_modules} )); then
	if [[ "$ZPROFILE_REPO" == "${ZDOTDIR:A}" ]]; then
		# Initialize submodules
		zupdate --submodules
	else
		# A shared ZDOTDIR (root's) must not fetch into the owner's repo
		print_fn -w "Submodules missing in $ZPROFILE_REPO; run 'zupdate --submodules' there as its owner."
	fi
fi

# ============================================================================
# Shared ZDOTDIR (root): warn when the copied startup files fall behind
# ============================================================================
# setup_root copies .zshenv & co. instead of linking them; nothing else updates
# those copies, so point at the fix when the repo's are newer (-nt: no fork).
if [[ "$ZPROFILE_REPO" != "${ZDOTDIR:A}" ]]; then
	local -a stale_files=()
	local zfile
	for zfile in .zshenv .zprofile .zshrc .zlogin .zlogout; do
		[[ "$ZPROFILE_REPO/$zfile" -nt "$ZDOTDIR/$zfile" ]] && stale_files+=($zfile)
	done
	unset zfile
	(( ${#stale_files} )) && print_fn -w "Outdated ${stale_files} in $ZDOTDIR; as the repo owner, run: zsh $ZPROFILE_REPO/conf/first_init.zsh setup_root"
fi

# ============================================================================
# Setup plugins environment
# ============================================================================
# Declare necessary global variables to be used at each stage of ZSH, so that
# they load plugins respectively.
# NOTE: This is NOT the place to store which plugins to load.

typeset -aU plugins=() # loaded at .zshrc (by OMZ or otherwise)
