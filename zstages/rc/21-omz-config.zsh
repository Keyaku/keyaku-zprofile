##############################################################################
# Oh-My-ZSH user configuration file
##############################################################################

# Check for Oh-My-ZSH; stop processing if not found
[[ -n "$ZSH" && -f "${ZSH}/oh-my-zsh.sh" ]] || return

# ============================================================================
# OMZ configuration
# ============================================================================

# Use case-sensitive completion.
CASE_SENSITIVE="true"

# Display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Change the command execution timestamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="dd/mm/yyyy"

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
(( ${+commands[ufw]} )) && plugins+=(ufw)

# Load plugins without aliases
local -aU _no_aliases=()
(( ${+commands[dotnet]} ))  && _no_aliases+=(dotnet)
(( ${+commands[flatpak]} )) && _no_aliases+=(flatpak)
(( ${+commands[git]} ))     && _no_aliases+=(git)
(( ${+commands[python]} || ${+commands[pip]} )) && _no_aliases+=(pip)

local f_plugin
for f_plugin in ${_no_aliases}; do
	zstyle ":omz:plugins:$f_plugin" aliases 0
done

plugins+=($_no_aliases)

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
