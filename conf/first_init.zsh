#!/usr/bin/env zsh

# Script to setup environment after Linux (or Termux) installation

readonly SCRIPT_DIR="${0:P:h}"
readonly SCRIPT_NAME="${0:P:t}"

# Prevent running as root or any privileged user
if (( $UID < 1000 )); then
	echo "${SCRIPT_NAME}: Current UID=$UID, and this should not be run by any privileged user!"
	return 1
# Prevent infinite recursion since this script is sourced in .zshrc
elif [[ -o login ]] || [[ -o interactive ]]; then
	echo "${SCRIPT_NAME}: This script should not be run in a login or interactive shell!"
	return 2
fi

####################
# Initialization
####################

[[ "$XDG_CONFIG_HOME" == "$HOME/.local/config" ]] || XDG_CONFIG_HOME="$HOME/.local/config"
[[ "$XDG_CACHE_HOME" == "$HOME/.local/cache" ]] || XDG_CACHE_HOME="$HOME/.local/cache"
[[ -d "${XDG_CACHE_HOME}"/zsh ]] || mkdir -p "${XDG_CACHE_HOME}/zsh"

(( ${+ZDOTDIR} )) || ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
(( ${+ZSH_CACHE_HOME} )) || ZSH_CACHE_HOME="${XDG_CACHE_HOME}/zsh"

# Source ZSH files just to be sure. Sourcing .zshrc will autoload all custom functions
local zfile zfiles=(.zshenv .zprofile .zshrc .zlogin)
for zfile in ${zfiles}; do
	source "$ZDOTDIR/$zfile" || {
		echo "${SCRIPT_NAME}: Error sourcing $zfile"
		return 1
	}
done

SUDO=$(whatami Android || echo sudo)
ROOT=$(whatami Android && echo /data/data/com.termux/files/usr)

typeset -rA templates=(
	[plugins.zsh]="plugins"
	[themes.zsh]=""
	# TODO: Uncomment these when ready
	# [pre-omz.zshrc]=""
	# [post-omz.zshrc]=""
)

typeset -i NEEDS_RESTART=0

####################
# Functions
####################

### Setup functions

# Installs system packages
function install_pkgs {
	local pkgs_needed=(rsync git zsh wget curl vim fastfetch)
	if ! command -v ${pkgs_needed} &>/dev/null; then
		if whatami Android; then
			local pkgs_termux=(getconf mount-utils)
			pkg install -y ${pkgs_needed} ${pkgs_termux}
		elif whatami Arch; then
			local pkgs_arch=(ttf-meslo-nerd flatpak plymouth power-profiles-daemon)
			sudo pacman -Syu --noconfirm ${pkgs_needed} ${pkgs_arch}
		fi
		# TODO: install for other systems
	fi
}

# Sets up ZSH system-wide to follow XDG Base Directory Specification
function setup_zsh {
	# Set zshenv file path
	local zshenv=$(echo "$ROOT"/etc/**/zshenv(N.))
	[[ -z "$zshenv" ]] && zshenv="$ROOT"/etc/zsh/zshenv

	# Add missing variables to zshenv
	if [[ ! -f "$zshenv" ]]; then
		NEEDS_RESTART=1
		$SUDO cp "$ZDOTDIR/conf/zsh/zshenv" "$zshenv"
	elif ! file_contents_in "$ZDOTDIR/conf/zsh/zshenv" "$zshenv"; then
		NEEDS_RESTART=1
		echo "Adding ZSH variables to system zshenv..."
		diff -u "$zshenv" "$ZDOTDIR/conf/zsh/zshenv" > "$ZSH_CACHE_HOME"/zshenv.patch
		$SUDO patch -su -d/ -p0 -i "$ZSH_CACHE_HOME"/zshenv.patch
	fi
}

# Sets up SSH system-wide to follow XDG Base Directory Specification
function setup_ssh {
	# Set ssh_config file paths
	local ssh_system="$ROOT"/etc/ssh

	# Synchronize SSH configuration files
	if ! file_contents_in "$ZDOTDIR/conf/ssh" "$ssh_system"; then
		echo "Synchronizing SSH conf..."
		$SUDO rsync -Przcq --no-t "$ZDOTDIR/conf/ssh/" "$ssh_system"
	fi
}

# Sets up systemd system-wide to follow XDG Base Directory Specification
function setup_systemd {
	# Synchronize systemd configuration files
	if ! file_contents_in "$ZDOTDIR/conf/systemd" /etc/systemd; then
		NEEDS_RESTART=1
		echo "Synchronizing systemd conf..."
		$SUDO rsync -Przcq --no-t "$ZDOTDIR/conf/systemd/" "/etc/systemd"
	fi
}

# Sets up Termux
function setup_termux {
	# Setup pkg mirrors
	if [[ ! -L "$ROOT"/etc/termux/chosen_mirrors ]]; then
		termux-change-repo
		pkg upgrade -y
	fi

	# Setup Termux storage
	[[ -d ~/storage ]] || termux-setup-storage

	# Add .termux configuration and scripts
	rsync -Przcq --no-t "$ZDOTDIR/conf/termux/" "$HOME/.termux"
	chmod ug+x "$HOME"/.termux/boot/**/*.sh(-.)

	# TODO: Install rish and add it to path
}

# Sets up XDG configuration and dotdirs locations
function setup_xdg {
	# Disable xdg-user-dirs-update from firing on every login
	if ! \grep -Eq '^enabled=True' /etc/xdg/user-dirs.conf; then
		sudo sed -i 's;^enabled=True;enabled=False;' /etc/xdg/user-dirs.conf
	fi

	# Relocate .config and .cache directories
	local -a dotdirs=(cache config)
	local dotdir
	for dotdir in ${dotdirs}; do
		if [[ -d "$HOME/.$dotdir" && ! -L "$HOME/.$dotdir" ]]; then
			rsync -Praz "$HOME/.$dotdir/" "$HOME/.local/$dotdir"
			rm -rf "$HOME/.$dotdir"
			ln -s "$HOME/.local/$dotdir" "$HOME/.$dotdir"
		fi
	done
}

# Sets up some pacman configuration and hooks
function setup_pacman {
	# Prepare rehash hook, to work with this repo's pacman plugin
	if [[ ! -f /etc/pacman.d/hooks/zsh.hook ]]; then
		[[ -d /etc/pacman.d/hooks ]] || $SUDO mkdir -p /etc/pacman.d/hooks
		$SUDO cp "$SCRIPT_DIR"/hooks/zsh.hook /etc/pacman.d/hooks/.
	fi
}

# Sets up Flatpak user repo and base packages
function setup_flatpak {
	local fp_install=user
	flatpak-remotes | \grep -q user || flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
	if flatpak-remotes | \grep -q system; then
		if ask -Bd y -p "Flatpak: Would you like to remove the default system flathub repo?"; then
			$SUDO flatpak --system remote-delete flathub
		else
			fp_install=system
		fi
	fi

	# Install base apps
	local -a fp_apps=(flatseal missioncenter)
	if ! flatpak-has -i ${fp_apps}; then
		flatpak --$fp_install --noninteractive -y install ${fp_apps}
	fi
}

# Sets up DE (Desktop Environment)
function setup_de {
	if [[ "$XDG_CURRENT_DESKTOP" == KDE ]]; then
		# Install required packages
		local -a pkgs_needed=(kdeconnect)
		whatami Arch && $SUDO pacman -S ${pkgs_needed}
		# FIXME: Set Monospace font to the insalled Meslo Nerd font
		#qt6ct -set monospace_font "MesloLGS Nerd Font Mono"

	fi
	# TODO: Add other DEs
}

### Function filters

# Base functions for all platforms
typeset -ra BASE_FUNCTIONS=(install_pkgs setup_zsh setup_ssh)
# Android functions
typeset -ra ANDROID_FUNCTIONS=(setup_termux)
# Linux functions
typeset -ra LINUX_FUNCTIONS=(setup_xdg setup_flatpak setup_de)
# Arch Linux functions
typeset -ra ARCH_FUNCTIONS=(setup_pacman)

### Main function

function main {
	# Gather all functions to run
	local -A fn_results
	local -a fn_to_run=($BASE_FUNCTIONS)
	if whatami Android; then
		fn_to_run+=($ANDROID_FUNCTIONS)
	else
		fn_to_run+=($LINUX_FUNCTIONS)
		has_systemd && fn_to_run+=(setup_systemd)
		whatami Arch && n_to_run+=($ARCH_FUNCTIONS)
	fi

	local -i fn_completed=0 fn_total=${#fn_to_run}

	# Run all functions
	local fn_current
	for fn_current in ${fn_to_run}; do
		fn_results[$fn_current]=0
		if $fn_current; then
			(( fn_completed++ ))
			fn_results[$fn_current]=1
		fi
	done
	fn_completed=${(vM)#fn_results:#1}
	local -a fn_failed=(${(k)fn_results[(R)0]})

	echo "$fn_completed/$fn_total" > "$SCRIPT_DIR/.first_init"

	# Mini report
	if (( $fn_completed/$fn_total )); then
		echo "${SCRIPT_NAME}: First-time initialization completed successfully."
		if (( $NEEDS_RESTART )); then
			echo "${SCRIPT_NAME}: Restart your system for changes to take effect."
		fi
		# if ask -B -d n "Would you like to create the base files for your custom configuration of .zshrc (pre-omz, themes, plugins, post-omz)?"; then
		# 	local zsh_template zsh_path
		# 	echo "Creating base files..."
		# 	for zsh_template zsh_path in ${templates}; do
		# 		cp "$ZDOTDIR/templates/$zsh_template.zsh-template" "$ZSH_CUSTOM/$zsh_path/$zsh_template"
		# 		printf '- %s\n' "$zsh_path/$zsh_template"
		# 	done
		# fi
	else
		print_fn -w "$fn_completed/$fn_total functions completed."
		echo "${SCRIPT_NAME}: The following functions failed: ${fn_failed}"
		return 1
	fi
}

####################
# Main
####################

main $@
