#####################################################################
#                            .zshrc
#
# File loaded 3rd && if [[ -o interactive ]]
#
# Used for setting user's interactive shell configuration
# and executing commands, will be read when starting
# as an *interactive shell*.
#####################################################################

# Path to your oh-my-zsh installation.
export ZSH="$ZDOTDIR/ohmyzsh"

# Changing some zsh variables
ZSH_CUSTOM="$ZDOTDIR/custom"

# Required setopts for this setup to work
setopt extendedglob
setopt re_match_pcre

### Detect if this is an interactive login shell (interactive is implied in .zshrc)
if [[ -o login ]]; then
	### First-time initialization
	if (( $UID >= 1000 )) && [[ ! -f "$ZDOTDIR/conf/.first_init" ]] || (( 1 != $(cat "$ZDOTDIR/conf/.first_init") )); then
		zsh "$ZDOTDIR"/conf/first_init.zsh
	fi

	### Print fetch
	(fetch=fastfetch
		if (( ${+commands[$fetch]} )); then
			$fetch
		else
			print_fn -e "%s\n" "'$fetch' is not installed."
		fi
	)
else
	# Load all custom functions
	autoload -Uz "$ZSH_CUSTOM"/functions/{.,^.}**/zsource(.N) && zsource -a
fi

#####################################################################

# TODO: Load user configuration pre-ohmyzsh
# [[ -f "$ZSH_CUSTOM"/pre-omz.zshrc ]] && source "$ZSH_CUSTOM"/pre-omz.zshrc

# Uncomment the following line to use case-sensitive completion.
CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="dd/mm/yyyy"

#####################################################################

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

# ohmyzsh plugins to load
typeset -aU plugins=()

# TODO: Load personal plugins configuration
# [[ -f "$ZSH_CUSTOM"/plugins/plugins.zsh ]] && source "$ZSH_CUSTOM"/plugins/plugins.zsh

# ohmyzsh plugins
plugins=(python pip ufw)
(( ${+functions[command_not_found_handler]} )) || plugins+=(command-not-found)

# Prepare ohmyzsh specifically for this configuration
zstyle ':omz:update' mode disabled  # disable automatic updates
# Load ohmyzsh
source "$ZSH"/oh-my-zsh.sh

# Bash modules & autocompletion (for programs which contain only bash completions)
if [[ -d "$XDG_DATA_HOME"/bash-completion/completions ]]; then
	autoload bashcompinit && bashcompinit && \
	for f_bashcomp in "$XDG_DATA_HOME"/bash-completion/completions/*(-N.); do
		source "$f_bashcomp"
	done
	unset f_bashcomp
fi

#####################################################################

# TODO: Load user configuration post-ohmyzsh
# [[ -f "$ZSH_CUSTOM"/post-omz.zshrc ]] && source "$ZSH_CUSTOM"/post-omz.zshrc

# ZSH modules
zmodload zsh/zutil # zparseopts

# Preferred editor
export EDITOR='vim'

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.

# powerlevel10k. To customize prompt, run `p10k configure` or edit $ZDOTDIR/.p10k.zsh.
[[ "$ZSH_THEME" == "powerlevel10k" && -f "$ZDOTDIR"/.p10k.zsh ]] && source "$ZDOTDIR"/.p10k.zsh
(( ${+ZDOTDIR} )) # Safety 0 return value
