#####################################################################
#    Oh-My-ZSH configuration file
#####################################################################

# Path to oh-my-zsh installation.
export ZSH="$ZDOTDIR/vendor/ohmyzsh"

# Uncomment the following line to use case-sensitive completion.
CASE_SENSITIVE="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="dd/mm/yyyy"

#####################################################################
### Themes

# Check for p10k; if non-existent, use robbyrussel
if [[ -L "${ZSH_CUSTOM}/themes/powerlevel10k.zsh-theme" ]]; then
	ZSH_THEME="powerlevel10k"

	# Enable Powerlevel10k instant prompt. Should stay close to the top of .zshrc.
	# Initialization code that may require console input (password prompts, [y/n]
	# confirmations, etc.) must go above this block; everything else may go below.
	if [[ "$POWERLEVEL9K_INSTANT_PROMPT" != "off" && -r "${ZSH_CACHE_HOME}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
		source "${ZSH_CACHE_HOME}/p10k-instant-prompt-${(%):-%n}.zsh"
	fi
else
	ZSH_THEME="robbyrussell"
fi

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

#####################################################################
### Source OMZ

# Prepare ohmyzsh specifically for this configuration
zstyle ':omz:update' mode disabled  # disable automatic updates
# Load ohmyzsh
source "$ZSH"/oh-my-zsh.sh
