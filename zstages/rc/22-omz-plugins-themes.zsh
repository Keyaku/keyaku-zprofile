##############################################################################
# Oh-My-ZSH plugins & themes
##############################################################################

# ============================================================================
# OMZ plugins
# ============================================================================

# Important notes:
# ----------------
# OMZ has this issue where, even if the user hasn't the tools related to a
# plugin (e.g. doesn't have python installed), rendering the plugin useless,
# OMZ still goes through a heavy process of loading them and adding them to
# `fpath`, regardless of whether the plugin returned early (especially with a
# value >0) or if had executed any code at all. This adds a massive overhead
# unnecessarily.
# Because of this, plugins to load should be carefully considered so as to not
# bloat the login times.

(( ${+functions[command_not_found_handler]} )) || plugins+=(command-not-found)

(( ${+command[git]} )) && plugins+=(git)
(( ${+command[python]} && ${+command[pip]} )) && plugins+=(python pip)
(( ${+command[ufw]} )) && plugins+=(ufw)
(( ${+command[flatpak]} )) && plugins+=(flatpak)


# ============================================================================
# OMZ themes
# ============================================================================

# Set default theme if not yet set
if [[ -z "$ZSH_THEME" ]]; then
	ZSH_THEME="robbyrussell"
fi

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )
