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
ZSH_COMPDUMP="$ZSH_CACHE_HOME/zcompdump-${SHORT_HOST}-${ZSH_VERSION}"

# Required setopts for this setup to work
setopt extendedglob
setopt re_match_pcre

### Detect if this is an interactive login shell (interactive is implied in .zshrc)
if [[ -o login ]]; then
	### First-time initialization
	if [[ ! -f "$ZDOTDIR/conf/.first_init" ]] || (( 1 != $(cat "$ZDOTDIR/conf/.first_init") )); then
		zsh "$ZDOTDIR"/conf/first_init.zsh
	fi
else
	# Load all custom functions
	autoload -Uz "$ZSH_CUSTOM"/functions/{.,^.}**/zsource(.N) && zsource -a
fi

#####################################################################

# TODO: Load user configuration pre-ohmyzsh
# [[ -f "$ZSH_CUSTOM"/pre-omz.zshrc ]] && source "$ZSH_CUSTOM"/pre-omz.zshrc

### Detect if this is an interactive login shell (interactive is implied in .zshrc)
if [[ -o login ]]; then
	### If on Android, sync with local storage Syncthing directory
	if whatami Android; then
		## Setup function to sync between Termux and local storage. Useful when synchronizing storage files (e.g. with SyncThing)
		TERMUX_SYNC_DIR=~/storage/shared/Documents/Workspaces/Termux
		if [[ -d "$TERMUX_SYNC_DIR" ]]; then
			export TERMUX_SYNC_DIR
			function termux-rsync {
				local direction="${1:-both}"
				local path_termux=~ path_ext="$TERMUX_SYNC_DIR"
				local path_lists=$HOME/.local/src/android/Termux

				[[ -d "$path_lists" ]] || path_lists=${path_ext}/.local/src/android/Termux
				if [[ ! -d "$path_lists" ]]; then
					print_fn -e "Could not find path lists directory."
					return 1
				fi

				if [[ "$direction" == "in" || "$direction" == "both" ]]; then
					rsync -Przc --no-t --exclude-from=$path_lists/android.exclude.in.txt ${path_ext}/. ${path_termux} || return 1
				fi
				if [[ "$direction" == "out" || "$direction" == "both" ]]; then
					rsync -Przc --files-from=$path_lists/android.include.out.txt --exclude-from=$path_lists/android.exclude.out.txt ${path_termux} ${path_ext} || return 1
				fi
			}
			## Sync changes
			termux-rsync
		else
			unset TERMUX_SYNC_DIR
		fi
	fi

	### Print fetch
	(fetch=fastfetch
		if (( ${+commands[$fetch]} )); then
			$fetch
		else
			print_fn -e "%s\n" "'$fetch' is not installed."
		fi
	)
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of .zshrc.
if [[ "$POWERLEVEL9K_INSTANT_PROMPT" != "off" && -r "${ZSH_CACHE_HOME}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
	source "${ZSH_CACHE_HOME}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

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

# ohmyzsh plugins to load
typeset -aU plugins=()
# Plugins to load natively (to avoid massive overhead from _omz_source)
typeset -aU native_plugins=()

# TODO: Load personal plugins configuration
# [[ -f "$ZSH_CUSTOM"/plugins/plugins.zsh ]] && source "$ZSH_CUSTOM"/plugins/plugins.zsh

# ohmyzsh plugins
plugins=(git python pip ufw)
(( ${+functions[command_not_found_handler]} )) || plugins+=(command-not-found)

# Plugins to load natively (to avoid omz's heavy overhead)
native_plugins=("$ZSH_CUSTOM"/plugins/(*~example)/*.plugin.zsh(-.N:h:t))

# Plugins to load via omz: all selected except those present in custom
plugins=(${plugins:|native_plugins})

# Prepare ohmyzsh specifically for this configuration
zstyle ':omz:update' mode disabled  # disable automatic updates
# Load ohmyzsh
source "$ZSH"/oh-my-zsh.sh

# Load native plugins
for plugin ($native_plugins); do
	source "$ZSH_CUSTOM/plugins/$plugin/$plugin.plugin.zsh"
done
unset plugin

# Bash modules & autocompletion (for programs which contain only bash completions)
if test "$XDG_DATA_HOME"/bash-completion/completions(FN); then
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
[[ -f "$ZDOTDIR"/.p10k.zsh ]] && source "$ZDOTDIR"/.p10k.zsh
