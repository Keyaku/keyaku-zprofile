#!/usr/bin/env zsh

# Script to setup environment after Linux (or Termux) installation

readonly SCRIPT_NAME=${0##*/}
readonly SCRIPT_DIR=${0:a:h}

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

(( ${+ZDOTDIR} )) || ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.local/config}/zsh"

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


####################
# Functions
####################

### Auxiliary functions

# Checks if file1's contents are in file2
function file_contents_in {
	check_argc 2 2 $# || return $?
	local file1="${1:a}"
	local file2="${2:a}"
	local differences="$(diff -r "$file1" "$file2" | sed -En '/^</p')"
	[[ -z "$differences" ]]
}

### Setup functions

# Installs system packages
function install_pkgs {
	local pkgs_needed=(getconf rsync git zsh wget curl vim fastfetch)
	if ! command -v ${pkgs_needed[@]} &>/dev/null; then
		whatami Android && pkg install -y ${pkgs_needed[@]}
		# TODO: install for other systems
	fi
}

# Sets up ZSH system-wide to follow XDG Base Directory Specification
function setup_zsh {
	# Set zshenv file path
	local zshenv=$(echo "$ROOT"/etc/**/zshenv(N.))
	[[ -z "$zshenv" ]] && zshenv="$ROOT"/etc/zsh/zshenv

	# Add ZDOTDIR to zshenv if not present
	if [[ ! -f "$zshenv" ]] || ! \grep -qw 'ZDOTDIR=' "$zshenv"; then
		echo "Adding ZDOTDIR to system zshenv..."
		echo 'export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.local/config}/zsh"' | $SUDO tee -a "$zshenv"
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
}

# Sets up XDG configuration
function setup_xdg {
	# Disable xdg-user-dirs-update from firing on every login
	if ! grep -Eq '^enabled=True' /etc/xdg/user-dirs.conf; then
		sudo sed -i 's;^enabled=True;enabled=False;' /etc/xdg/user-dirs.conf
	fi
}

### Function filters

# Base functions for all platforms
typeset -ra BASE_FUNCTIONS=(install_pkgs setup_zsh setup_ssh)
# Android functions
typeset -ra ANDROID_FUNCTIONS=(setup_termux)
# Linux functions
typeset -ra LINUX_FUNCTIONS=(setup_xdg setup_systemd)

### Main function

function main {
	# Gather all functions to run
	local -A fn_results
	local -a fn_to_run=($BASE_FUNCTIONS)
	whatami Android && fn_to_run+=($ANDROID_FUNCTIONS)
	has_systemd && fn_to_run+=(setup_systemd)
	[[ -d "$ROOT"/etc/xdg ]] && fn_to_run+=(setup_xdg)

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

	echo "$fn_completed/$fn_total" > "$ZDOTDIR/.first_init"

	# Mini report
	if (( $fn_completed/$fn_total )); then
		echo "${SCRIPT_NAME}: First-time initialization completed successfully."
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
