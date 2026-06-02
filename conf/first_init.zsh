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
	local pkgs_needed=(rsync patch git zsh wget curl vim fastfetch)
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
	[[ ! -d "${zshenv:h}" ]] && zshenv="$ROOT"/etc/zshenv

	# Add missing variables to zshenv
	if [[ ! -f "$zshenv" ]]; then
		NEEDS_RESTART=1
		$SUDO cp "$ZDOTDIR/conf/etc/zsh/zshenv" "$zshenv"
	elif ! file_contents_in -q "$ZDOTDIR/conf/etc/zsh/zshenv" "$zshenv"; then
		NEEDS_RESTART=1
		echo "Adding ZSH variables to system zshenv..."
		diff -u "$zshenv" "$ZDOTDIR/conf/etc/zsh/zshenv" > "$ZSH_CACHE_HOME"/zshenv.patch
		$SUDO patch -su -d/ -p0 -i "$ZSH_CACHE_HOME"/zshenv.patch
	fi
}

# Sets up SSH system-wide to follow XDG Base Directory Specification
function setup_ssh {
	# Set ssh_config file paths
	local ssh_system="$ROOT"/etc/ssh

	# Synchronize SSH configuration files
	if ! file_contents_in -q "$ZDOTDIR/conf/etc/ssh" "$ssh_system"; then
		echo "Synchronizing SSH conf..."
		$SUDO rsync -rzcq --no-t "$ZDOTDIR/conf/etc/ssh/" "$ssh_system"
	fi
}

# Sets up systemd system-wide to follow XDG Base Directory Specification
function setup_systemd {
	# Synchronize /etc/systemd. -p preserves the source file modes so the
	# system-sleep helper stays 0755 while drop-in .conf files stay 0644.
	if ! file_contents_in -q "$ZDOTDIR/conf/etc/systemd" /etc/systemd; then
		NEEDS_RESTART=1
		echo "Synchronizing systemd conf..."
		$SUDO rsync -rzcpq --no-t "$ZDOTDIR/conf/etc/systemd/" "/etc/systemd"
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
	rsync -rzcq --no-t "$ZDOTDIR/conf/home/termux/" "$HOME/.termux"
	local -a boot_scripts=("$HOME"/.termux/boot/**/*.sh(-.N))
	(( ${#boot_scripts} )) && chmod ug+x ${boot_scripts}

	# TODO: Install rish and add it to path
	return 0
}

# Sets up XDG configuration and dotdirs locations
function setup_xdg {
	# Disable xdg-user-dirs-update from firing on every login
	if [[ ! -f "$XDG_CONFIG_HOME"/user-dirs.conf ]] || ! \grep -Eq '^enabled=True' "$XDG_CONFIG_HOME"/user-dirs.conf; then
		touch "$XDG_CONFIG_HOME"/user-dirs.conf
		sed -i 's;^enabled=True;enabled=False;' "$XDG_CONFIG_HOME"/user-dirs.conf
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
		$SUDO cp "$SCRIPT_DIR"/etc/pacman/hooks/zsh.hook /etc/pacman.d/hooks/.
	fi
}

# Installs this ZSH environment for the root user (sparse ZDOTDIR: symlinked
# code dirs, copied startup files, independent user-config space).
function setup_root {
	(( ${+commands[sudo]} )) || return 1

	ask -Bd n -p "Would you like to install this ZSH environment for the root user?" || return 0

	local root_home=$(getent passwd root | cut -d: -f6)
	local root_zdotdir="${root_home}/.local/config/zsh"

	if [[ -d "$root_zdotdir" && ! -L "$root_zdotdir" ]]; then
		sudo mv "$root_zdotdir" "${root_zdotdir}.bak"
		print_fn -i "Backed up $root_zdotdir to ${root_zdotdir}.bak"
	fi

	sudo mkdir -p "$root_zdotdir"

	# Symlink shared code directories — always reflect the live repo state
	local dir
	for dir in lib extensions zstages vendor conf; do
		[[ -e "$ZDOTDIR/$dir" ]] || continue
		sudo ln -sfn "$ZDOTDIR/$dir" "$root_zdotdir/$dir"
	done

	# Independent: root has its own custom dir and no .p10k.zsh by default
	sudo mkdir -p "$root_zdotdir/custom/themes"

	# Symlink the powerlevel10k theme so root can opt into p10k by dropping a
	# .p10k.zsh into its $ZDOTDIR (10-setup.zsh gates ZSH_THEME on this file).
	if [[ -e "$ZDOTDIR/vendor/themes/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
		sudo ln -sfn "$ZDOTDIR/vendor/themes/powerlevel10k/powerlevel10k.zsh-theme" \
			"$root_zdotdir/custom/themes/powerlevel10k.zsh-theme"
	fi

	# Copy startup entry point files (stable boilerplate; sync manually if they change)
	local f
	for f in .zshenv .zprofile .zshrc .zlogin .zlogout; do
		[[ -f "$ZDOTDIR/$f" ]] || continue
		sudo cp "$ZDOTDIR/$f" "$root_zdotdir/$f"
	done

	print_fn -s "Root ZSH environment installed at $root_zdotdir."
}

# Sets up Flatpak user repo and base packages
function setup_flatpak {
	local fp_install=user
	flatpak-installations | \grep -q user || flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
	if flatpak-installations | \grep -q system; then
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
	return 0
}

# Symlinks this repo's borg config into $XDG_CONFIG_HOME/borg so borg-backup.zsh
# (run as root via sudo) finds borg-config.json + excludes/. Per-host settings
# go in borg-config.override.json — gitignored via `*.override.*`.
function setup_borg {
	command-has borg || return 0

	# Repo passphrase: /etc/borg (0700) holds the plaintext passphrase (0400),
	# the source of truth from which a host can derive a systemd-creds encrypted
	# credential. Generate once and never overwrite — clobbering it would orphan
	# any existing repo. SD formatting, the mount unit, the encrypted credential
	# and the per-host override config are deliberately NOT handled here; those
	# are one-shots that vary per machine.
	$SUDO install -d -m 0700 -o root -g root /etc/borg
	if ! $SUDO test -f /etc/borg/passphrase; then
		openssl rand -base64 48 | $SUDO tee /etc/borg/passphrase >/dev/null
		$SUDO chmod 0400 /etc/borg/passphrase
		$SUDO chown root:root /etc/borg/passphrase
		print_fn -s "Generated borg passphrase: /etc/borg/passphrase"
	fi

	local src="$ZDOTDIR/conf/home/borg"
	local dest="${XDG_CONFIG_HOME:-$HOME/.local/config}/borg"

	[[ -L "$dest" && "$(readlink -f "$dest")" == "$src" ]] && return 0

	if [[ -e "$dest" && ! -L "$dest" ]]; then
		mv "$dest" "${dest}.bak"
		print_fn -i "Backed up $dest to ${dest}.bak"
	fi

	mkdir -p "${dest:h}"
	ln -sfn "$src" "$dest"
	print_fn -s "Borg config linked: $dest -> $src"

	# Expose the nightly runner on sudo's secure_path so `sudo borg-backup.zsh`
	# resolves. The target provisioner (conf/tools/borg-target.zsh) is a
	# once-per-host one-shot and is deliberately NOT linked — run it by path.
	local script="$ZDOTDIR/conf/home/bin/borg-backup.zsh"
	local bin="/usr/local/bin/borg-backup.zsh"
	if [[ ! -L "$bin" || "$(readlink -f "$bin")" != "$script" ]]; then
		$SUDO ln -sfn "$script" "$bin"
		print_fn -s "Borg script linked: $bin -> $script"
	fi
}

# Provisions the least-privilege `claude` automation user for Claude Code: its
# restricted sudo policy, the dctl Docker-control wrapper and the SessionStart
# profile hook. Skipped if docker is absent. The provisioner is a once-per-host
# one-shot (it creates a user), so it is run by path rather than auto-applied
# on every login. Re-running is idempotent.
function setup_claude {
	command-has docker || return 0

	local script="$ZDOTDIR/conf/tools/claude-sandbox.zsh"
	[[ -x "$script" ]] || return 0

	if id claude &>/dev/null; then
		print_fn -i "claude automation user already present — re-run $script by hand to refresh policy"
		return 0
	fi

	if ask -B -d n "Provision the least-privilege 'claude' user for Claude Code now?"; then
		"$script" || { print_fn -w "claude-sandbox provisioning failed"; return 1; }
		print_fn -s "claude automation user provisioned."
	fi
}

### Repo-local setup

# Points this repo's git hooksPath at conf/hooks so the pre-commit completion
# drift check runs on commits that touch lib/ or completions/.
function setup_git_hooks {
	(( ${+commands[git]} )) || return 1
	[[ -d "$ZDOTDIR/.git" ]] || return 0

	local current
	current=$(git -C "$ZDOTDIR" config --local --default '' core.hooksPath)
	[[ "$current" == "conf/hooks" ]] && return 0

	if [[ -n "$current" ]]; then
		print_fn -w "core.hooksPath is already set to '$current' — leaving as-is"
		return 0
	fi

	ask -Bd y -p "Enable repo pre-commit hook for completions drift check (sets core.hooksPath=conf/hooks)?" || return 0

	git -C "$ZDOTDIR" config --local core.hooksPath conf/hooks
	print_fn -s "Pre-commit hook enabled."
}

### Function filters

# Base functions for all platforms
typeset -ra BASE_FUNCTIONS=(install_pkgs setup_zsh setup_ssh setup_git_hooks)
# Android functions
typeset -ra ANDROID_FUNCTIONS=(setup_termux)
# Linux functions
typeset -ra LINUX_FUNCTIONS=(setup_xdg setup_de setup_root setup_borg setup_claude)
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
		command-has flatpak && fn_to_run+=(setup_flatpak)
		has_systemd && fn_to_run+=(setup_systemd)
		whatami Arch && fn_to_run+=($ARCH_FUNCTIONS)
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
