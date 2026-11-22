# ============================================================================
# First-time initialization check
# ============================================================================
if (( $UID >= 1000 )) && { [[ ! -f "$ZDOTDIR/conf/.first_init" ]] || (( 1 != $(<"$ZDOTDIR/conf/.first_init") )) }; then
	print -u2 "Warning: The ZSH profile was not initialized. Run the following command to ensure everything works as expected:"
	printf "\t%s\n" "zsh "$ZDOTDIR"/conf/first_init.zsh"
fi

# ============================================================================
# Fetch vendored repos that are enabled but not cloned yet
# ============================================================================
# conf/vendor.tsv lists them (see _zvendor_entries); a missing one has no .git.
local -a reply missing_vendor=()
local vname vpath vurl vbranch
if _zvendor_entries; then
	for vname vpath vurl vbranch in $reply; do
		_zsubmodule_enabled "$vname" && [[ ! -e "$ZPROFILE_REPO/$vpath/.git" ]] && missing_vendor+=($vpath)
	done
fi
unset vname vpath vurl vbranch
if (( ${#missing_vendor} )); then
	if [[ "$ZPROFILE_REPO" == "${ZDOTDIR:A}" ]]; then
		zupdate --submodules
	else
		# A shared ZDOTDIR (root's) must not clone into the owner's repo
		print_fn -w "Vendored repos missing in $ZPROFILE_REPO (${missing_vendor}); run 'zupdate --submodules' there as its owner."
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
