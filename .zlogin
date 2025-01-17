#####################################################################
#                            .zlogin
#
# File loaded 4th && if [[ -o login ]]
#
# Used for executing user's commands at ending of initial progress,
# will be read when starting as a login shell.
# Typically used to autostart command line utilities.
# Should not be used to autostart graphical sessions,
# as at this point the session might contain configuration
# meant only for an interactive shell.
#####################################################################


# ssh-agent-start

# Function to setup environment after Linux (or Termux) installation
function first_init {
	if (( $UID < 1000 )); then
		echo "Current UID=$UID, and this should not be run by any privileged user!"
		return 1
	fi

	local pkgs_needed=(getconf rsync git zsh wget curl vim fastfetch)
	if ! command -v ${pkgs_needed[@]} &>/dev/null; then
		whatami Android && pkg install -y ${pkgs_needed[@]}
	fi

	# Get ohmyzsh
	[[ -d ~/.local/git ]] || mkdir -p ~/.local/git
	[[ -d ~/.local/git/ohmyzsh ]] || ZSH=~/.local/git/ohmyzsh sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	# Get ohmyzsh themes
	local zsh_themes="${ZSH_CUSTOM:-$HOME/.local/git/ohmyzsh/custom}/themes"
	[[ -d $zsh_themes/powerlevel10k ]] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $zsh_themes/powerlevel10k
	[[ -L $zsh_themes/powerlevel10k.zsh-theme ]] || (cd $zsh_themes
		ln -s powerlevel10k/powerlevel10k.zsh-theme powerlevel10k.zsh-theme
	)
	# Get ohmyzsh plugins
	local zsh_plugins="${ZSH_CUSTOM:-$HOME/.local/git/ohmyzsh/custom}/plugins"
	[[ -d $zsh_plugins/zsh-syntax-highlighting ]] || git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $zsh_plugins/zsh-syntax-highlighting

	# Setup ZSH and SSH
	if whatami Android; then
		[[ -f "$HOME/../usr/etc/zshenv" ]] && touch "$HOME/../usr/etc/zshenv"
		if [[ -z "$(sed -En '/ZDOTDIR/{p;q;}')" ]]; then
			echo 'export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.local/config}/zsh"' >> "$HOME/../usr/etc/zshenv"
		fi
		# TODO: setup SSH config
		TERMUX_HOME=~/storage/shared/Documents/Workspaces/Termux
		if [[ ! -f "$HOME/../usr/etc/ssh/ssh_config.d/user.conf" ]]; then
			rsync -Przc --no-t "$HOME/.local/src/android/Termux/ssh" "$HOME/../usr/etc/ssh/"
		fi
		unset TERMUX_HOME
	else
		: # TODO: Generic installation setup

		# Disable xdg-user-dirs-update from firing on every login
		grep -Eq '^enabled=True' /etc/xdg/user-dirs.conf && sudo sed -i 's;^enabled=True;enabled=False;' /etc/xdg/user-dirs.conf

		# systemd-specific configuration
		if [[ "$(ps --no-headers -o comm 1)" == "systemd" ]]; then
			# Set systemd UnitPath to specific (in this case, XDG) path
			if [[ ! -f /etc/systemd/user.conf.d/xdg.conf ]]; then
				sudo mkdir -p /etc/systemd/user.conf.d
				{ echo '[Manager]'
					echo 'ManagerEnvironment="XDG_CONFIG_HOME=%h/.local/config"'
					echo 'ManagerEnvironment="XDG_CACHE_HOME=%h/.local/cache"'
					echo 'ManagerEnvironment="SYSTEMD_UNIT_PATH=%h/.local/config/systemd:"'
				} | sudo tee /etc/systemd/user.conf.d/xdg.conf >/dev/null
			fi
		fi
	fi

}


### Detect if this is an interactive shell login
if [[ -o login ]] && [[ -o interactive ]]; then
	### If on Android, sync with Syncthing directory
	if whatami Android; then
		## Check if everything is setup on Termux
		[[ -d ~/storage ]] || termux-setup-storage
		first_init

		## Setup function to sync between Termux and local storage. Useful when synchronizing storage files (e.g. with SyncThing)
		TERMUX_HOME=~/storage/shared/Documents/Workspaces/Termux
		if [[ -d "$TERMUX_HOME" ]]; then
			export TERMUX_HOME
			function termux-rsync {
				local direction="${1:-both}"
				local path_termux=~ path_ext="$TERMUX_HOME"
				local path_lists=$HOME/.local/src/android/Termux

				[[ -d "$path_lists" ]] || path_lists=${path_ext}/.local/src/android/Termux

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
			unset TERMUX_HOME
		fi
	else
		### Session type (X11, Wayland) configuration
		if [[ -z "${XDG_SESSION_TYPE}" ]] && command -v loginctl &>/dev/null; then
			export XDG_SESSION_TYPE="$(loginctl show-session $(awk '/tty/ {print $1}' <(loginctl)) -p Type | awk -F= '{print $2}')"
		fi
	fi
fi
