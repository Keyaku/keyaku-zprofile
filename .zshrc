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

# Changing custom folder from $ZSH/custom to $ZDOTDIR/custom
ZSH_CUSTOM="$ZDOTDIR/custom"

# Performance profile: Uncomment this first
# zmodload zsh/zprof

### Detect if this is an interactive shell login
if [[ -o login ]] && [[ -o interactive ]]; then
	### Print fetch
	(fetch=fastfetch
		if command -v $fetch &>/dev/null; then
			$fetch
		else
			printf "%s\n" "'$fetch' is not installed."
		fi
	)
fi

# Generic setopts
setopt extendedglob
setopt re_match_pcre

# Load function that loads all custom functions
autoload -Uz "${ZSH_CUSTOM}"/functions/{.,^.}**/load_zfunc(N) && load_zfunc

# Enable Powerlevel10k instant prompt. Should stay close to the top of .zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ "$POWERLEVEL9K_INSTANT_PROMPT" != "off" && -r "${XDG_CACHE_HOME:-$HOME/.local/cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
	source "${XDG_CACHE_HOME:-$HOME/.local/cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
if [[ -L "${ZSH_CUSTOM}/themes/powerlevel10k.zsh-theme" ]]; then
	ZSH_THEME="powerlevel10k"
else
	ZSH_THEME="robbyrussell"
fi

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 7

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

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
	# ohmyzsh plugins
	git pip nmap
	# Custom plugins (load them all by default)
    "$ZSH_CUSTOM"/plugins/(*~example)(-FN:t)
)
# Add OS-specific plugins
whatami Arch && plugins+=(archlinux)

source $ZSH/oh-my-zsh.sh


#### User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# Bash modules & autocompletion (for programs which contain only bash completions)
autoload bashcompinit && bashcompinit
[[ -e "$XDG_DATA_HOME/bash-completion/completions/appman" ]] && source "$XDG_DATA_HOME/bash-completion/completions/appman"

# ZSH modules
zmodload zsh/zutil # zparseopts

# On-demand bin rehash
zshcache_time="$(date +%s%N)"
autoload -Uz add-zsh-hook
rehash_precmd() {
	if [[ -a /var/cache/zsh/pacman ]]; then
		local paccache_time="$(date -r /var/cache/zsh/pacman +%s%N)"
		if (( zshcache_time < paccache_time )); then
			rehash
			zshcache_time="$paccache_time"
		fi
	fi
}
add-zsh-hook -Uz precmd rehash_precmd

# command-not-found handler
command -v pkgfile &>/dev/null && {
	source /usr/share/doc/pkgfile/command-not-found.zsh
}

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.

# powerlevel10k. To customize prompt, run `p10k configure` or edit $ZDOTDIR/.p10k.zsh.
[[ -f "$ZDOTDIR"/.p10k.zsh ]] && source "$ZDOTDIR"/.p10k.zsh

# Performance profile: Uncomment this second
# zprof
