##############################################################################
# Oh-My-ZSH load file
##############################################################################

# Check for Oh-My-ZSH; stop processing if not found
[[ -n "$ZSH" && -f "$ZSH/oh-my-zsh.sh" ]] || return

# In case a user would like to keep OMZ's full functionality, instead of the
# alternative implementation.
local load_omz
if zstyle -b ':zprofile:submodules:ohmyzsh' loaded load_omz; then
	# Load ohmyzsh
	_zsh_source_file "$ZSH"/oh-my-zsh.sh
	return 0
fi

# Otherwise, the rest of this file and 26-plugins.zsh will attempt to
# replicate omz with efficiency in mind.

# ============================================================================
# fpath setup
# ============================================================================
local -a fpath_candidates=(
	"$ZSH_CUSTOM/functions"
	"$ZSH_CUSTOM/completions"
)
local fpath_dir
for fpath_dir in $fpath_candidates; do
	[[ -d "$fpath_dir" ]] && (( ! ${fpath[(I)$fpath_dir]} )) && fpath=("$fpath_dir" $fpath)
done

# ============================================================================
# Load omz lib files (all except excluded)
# ============================================================================
local -a omz_libs_exclude=(
	bzr.zsh
	nvm.zsh
	diagnostics.zsh
	correction.zsh
	compfix.zsh
)
local lib
for lib in "$ZSH"/lib/*.zsh(N.on); do
	(( ${omz_libs_exclude[(I)${lib:t}]} )) || source "$lib"
done

# ============================================================================
# Load custom configurations from $ZSH_CUSTOM
# ============================================================================
local config_file
for config_file ("$ZSH_CUSTOM"/*.zsh(N)); do
	source "$config_file"
done

# ============================================================================
# Theme loading
# ============================================================================
if [[ -n "$ZSH_THEME" ]]; then
	local -a theme_dirs=(
		"$ZSH_CUSTOM"
		"$ZSH_CUSTOM/themes"
		"$ZSH/themes"
	)
	local -i theme_found=0
	local theme_dir
	for theme_dir in $theme_dirs; do
		if [[ -f "$theme_dir/$ZSH_THEME.zsh-theme" ]]; then
			source "$theme_dir/$ZSH_THEME.zsh-theme"
			theme_found=1
			break
		fi
	done
	(( theme_found )) || print_fn -w "theme '$ZSH_THEME' not found"
fi

# ============================================================================
# Completion colors
# ============================================================================
[[ -z "$LS_COLORS" ]] || zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
