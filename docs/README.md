# Keyaku's ZDOTDIR configuration

A whole set of profile and utilities to improve my daily use of ZSH.

## Description

**NOTE**: This is an environment for **ZSH** _only_. **Do _not_ attempt** to use this with `bash`, `fish` or any other shell.

### Summary

This is a comprehensive list of profile files, loaded at boot, login or interactive shell, filled with auxiliary functions and lifesavers.
Currently, it's not meant to replace anyone's current profile configuration, although it is going to be the case as soon as I make it flexible to anybody who wishes to make use of the myriad of functions I wrote.
If any of the functions I introduce is already reproducible via some POSIX shell or ZSH substitution, sometimes even more elegantly or better in performance,
it's very likely that I am not aware of it, or haven't yet updated the function to reflect that.

I'm always willing to learn new tricks; I just haven't researched them all.

### Scope

The intent is to have a zsh session equipped with all sorts of functions, aliases and environment variables to:
- Have lifesavers to be used via command line, and/or to avoid boilerplate in scripts. 
- Prepare the appropriate environment for each installed program (e.g. set `GNUPGHOME` for `gnupg`) without manually specifying which programs to setup.
- Have an initialization code block which prepares (virtually) any new Linux distro installation.
- Attempt to clear the `$HOME` directory from dotfiles as much as possible, so it contains the bare minimum.
In case you'd like to find out which dotfiles currently sit in your home directory, one very quick way is with the following command:
```shell
echo $HOME/.*(:s,$HOME/,,)
```
The lower the number of these files, the better organized is my setup. This is, unfortunately, easier said than done due to principally developers not having adopted the XDG directory specification, or having implemented it poorly (by forcing a path instead of reading it from the environment).
For more info on each entry, I personally use [xdg-ninja](https://github.com/b3nj5m1n/xdg-ninja).

### Contents

This repo contains the fundamental profile files which allow me to use my Unix/Linux system with as little hassle as possible, and even start a fresh system install with a minimum of effort.  
It's structured as follows:
1. [ZSH startup profiles](https://wiki.archlinux.org/title/Zsh#Startup/Shutdown_files) under `$ZDOTDIR/`, sorted in order which they are loaded:
	1. `.zshenv` - Used for setting user's environment variables; it should not contain commands that produce output or assume the shell is attached to a TTY. When this file exists it will **_always_** be read.
		1. Defines `_zsh_source_file()` and `_zsh_source_dir()` functions to easily source through files, with benchmarking measurements (only if `$ZSH_PROFILE_BENCHMARK` is set).
		2. Loads every `.zsh` file in `lib/core/`.
		3. Loads every `.zsh` file in `zstages/env/`; the filenames reflect the priority for each file.
	2. `.zprofile` - Used for executing user's commands at start, will be read when starting as a **_login shell_**. Typically used to autostart graphical sessions and to set session-wide environment variables.
		1. Loads every `.zsh` file in `lib/login/`.
		2. Loads every `.zsh` file in `zstages/profile/`; the filenames reflect the priority for each file.
	3. `.zshrc` - Used for setting user's interactive shell configuration and executing commands, will be read when starting as an **_interactive shell_**.
		1. Loads every `.zsh` file in `lib/interactive/`.
		2. Loads every `.zsh` file in `zstages/rc/`; the filenames reflect the priority for each file.
	4. `.zlogin` - Used for executing user's commands at ending of initial progress, will be read when starting as a **_login shell_**. Typically used to autostart command line utilities. Should not be used to autostart graphical sessions, as at this point the session might contain configuration meant only for an interactive shell.
		1. Loads every `.zsh` file in `zstages/login/`; the filenames reflect the priority for each file.
2. My own set of plugins, named `extensions` to differentiate from custom plugins, under `extensions/`. The main points for this over putting them in `custom/plugins/` are:
	* All `extensions/` are loaded by default, while `custom/plugins/` depend on which plugins you insert into `plugins`. Any of them can be turned off with `zext` (see [Customization](#customization)).
	* Every extension contains first lines which serve as guards in case they're not needed to be loaded; for instance, you don't have docker installed, so the `docker` extension will return without doing anything.
	* The above ensure extensions are loaded only if the appropriate conditions are met, minimizing session login times while keeping the environment well equipped.
	* Completion files (`_*`) are not loaded or considered, avoiding `fpath` pollution.
	* They follow the same naming schemes and structure as `plugins`, including the `.plugin.zsh` filename extension.
	* A few extensions also provision host state on first load. For example, `ssh-agent` symlinks its user unit from `conf/home/systemd/user/ssh-agent.service` into `${XDG_CONFIG_HOME}/systemd/user/` (the repo copy is the source of truth, so the unit travels and self-heals across machines) and exports `SSH_AUTH_SOCK` from the agent's deterministic socket. The unit itself publishes `SSH_AUTH_SOCK` into the systemd/D-Bus session environment so graphical and Flatpak apps inherit it, while the extension covers shells that don't descend from the session manager (TTY logins, `--host` shells).
3. Zsh completions for `lib/` functions under `completions/`. One `_<funcname>` file per public function, prepended to `$fpath` before OMZ runs `compinit`. Drift between `lib/` and `completions/` is checked by `conf/check-completions.zsh` (invoked by `zupdate` and by the pre-commit hook at `conf/hooks/pre-commit`); `completions/.skip` lists intentionally uncompleted functions.
4. Custom functions under `custom/functions/`.
5. Custom plugins under `custom/plugins/`.
6. Custom themes under `custom/themes/`.
7. Your own settings and stage overrides under `user/` (gitignored; template in `conf/user.example/`).

### Dependencies

_Oh-My-ZSH_, _powerlevel10k_ and _zsh-syntax-highlighting_ are git submodules, enabled and loaded by default. Each can be turned off with `zsubmod --off <name>` in `user/settings.zsh` (see [Customization](#customization)); a disabled submodule is neither fetched by `zupdate --submodules` nor loaded.

Turning off _powerlevel10k_ or _zsh-syntax-highlighting_ is fully supported. Turning off _Oh-My-ZSH_ works, but nothing replaces it yet, so you also lose `compinit` and plugin loading.

#### Oh-My-ZSH

This addon is loaded at the usual `zshrc` stage after disabling auto-updates and having gone through any user configuration, in file `zstages/rc/25-omz-load.zsh`.
Its plugin loader was replaced by my own code, which is optimized as much as possible and avoids `fpath` pollution, guaranteeing faster load times than OMZ (based on current tests).

#### Powerlevel10k

This theme is set at the usual `zshrc` stage, before OMZ is loaded, with a code block in `zstages/rc/10-setup.zsh` that loads the cached instant prompt file if it's enabled.
The submodule's theme file is symlinked into `custom/themes/`, where OMZ finds it.
When the submodule is disabled or not checked out, a copy installed by the system's package manager is used instead (e.g. Arch's `zsh-theme-powerlevel10k`, Homebrew, NixOS). OMZ can't find that one, so `zstages/rc/90-user.zsh` sources it right before `.p10k.zsh`. The setup script offers to switch to it when it finds one. To skip powerlevel10k altogether, disable the submodule and set `ZSH_THEME` to another theme in `user/settings.zsh`.

#### zsh-syntax-highlighting

This plugin is sourced last in the `zshrc` stage, by `zstages/rc/95-syntax-highlighting.zsh`, since it wraps every ZLE widget defined before it. It doesn't go through OMZ.
When the submodule is disabled or not checked out, a copy installed by the system's package manager is used instead, if there is one. The setup script offers to switch to that copy when it finds one.

#### fastfetch

Although not added as a git submodule, the environment currently expects `fastfetch` to be installed, which is run at the `zshrc` stage in `zstages/rc/10-setup.zsh`, printing a one-time only warning in case it is not installed.
In the future, this block should be adapted to any fetch program of your choice.

## Practicality

### Installation

There's still some work to be done, particularly with the setup script, but most of the environment is at an acceptable stage for anyone to pick up and use.  
Currently, it works best with Arch Linux, but it should work with any Linux distro; some systems require a bit more tweaking due to differences in file layout.
If you are adventurous enough, the procedure is a bit straightforward (with plans to make it much easier in the future). The following presumes `$XDG_CONFIG_HOME` is set to `$HOME/.local/config` (later potentially being flexible to any other path _except `$HOME/.config`_): 

0. Make sure `zsh` is installed, and set as default shell:
```shell
sudo pacman -S zsh # Arch Linux command to install; this *will* differ with from other distros
chsh -s /bin/zsh # Change shell to zsh
```
1. Head to `$XDG_CONFIG_HOME` and clone this repository to a target directory named `zsh`:
```shell
cd "${XDG_CONFIG_HOME:-$HOME/.local/config}"
git clone https://github.com/Keyaku/keyaku-zprofile zsh
```
2. Run the initial setup script:
```shell
cd zsh
zsh conf/first_setup.zsh
```
3. Answer the script's prompts: it asks before each step (pass `-y` to run them all). Make sure it sets up everything correctly. It'll keep track of every substep in the file `.first_init` at the root of the git repo.
4. Log out and log back in.


### Customization

Right now, customization is feasible but not yet easy.

#### Your own overlay (`user/`)

Personal settings and overrides go in `$ZDOTDIR/user/`, which is gitignored, so updating the repo never touches it. Start from `conf/user.example/` (its README explains each file):

- `user/settings.zsh` is sourced by `.zshenv` right after `lib/core/`, before every stage, so it applies to every kind of shell. Use it for `zext`, `zsubmod` and plain variables such as `ZSH_THEME`.
- `user/<stage>/` (`env`, `profile`, `rc`, `login`, `logout`) is merged into `zstages/<stage>/`: all files are sourced together in filename order, so the number sets where yours runs. For example, `user/rc/22-omz.zsh` runs after `zstages/rc/21-omz-config.zsh` and before OMZ loads at 25, the place to change OMZ settings or add plugins.
- A file with the same name as a tracked one replaces it. `zupdate` warns when a tracked file you replaced changes upstream, so you can merge the changes in.
- `user/` can be a symlink, e.g. into a synced folder, to share it between machines.

#### Choosing what loads

Two functions, meant for `user/settings.zsh`, set what loads with the same syntax:

- `zext` for extensions: `zext --off docker vscode`, or `zext --off '*' --on git ssh` to load only a few (a name always wins over `'*'`).
- `zsubmod` for submodules: `zsubmod --off powerlevel10k`.

Run either with no arguments to list everything and whether it's on. Both just set zstyles (`':zprofile:extensions:<name>' enabled` and `':zprofile:submodules:<name>' enabled`), so setting those directly works too.

#### OMZ configuration, plugins, themes

The defaults from OMZ's `.zshrc` template are set in `zstages/rc/21-omz-config.zsh`, including the plugins and the theme. Adjust them from `user/rc/22-*.zsh`, or replace the file entirely with your own `user/rc/21-omz-config.zsh`.

### SSH

SSH is set up to follow the XDG Base Directory Specification, and its agent runs as a systemd user service.

#### Configuration layout

- `setup_ssh` (in `conf/first_init.zsh`) syncs `conf/etc/ssh/` into `/etc/ssh/`. The client drop-in `ssh_config.d/99-user.conf` points `IdentityFile` and `UserKnownHostsFile` at `${XDG_CONFIG_HOME}/ssh/` and includes `${XDG_CONFIG_HOME}/ssh/config.d/*`. The server drop-in `sshd_config.d/99-user.conf` disables password and root logins and reads keys from `.local/config/ssh/authorized_keys`.
- The `ssh` extension exports `SSH_HOME=${XDG_CONFIG_HOME}/ssh`, migrates a leftover `~/.ssh` into it, and creates the `agent`, `config.d`, `control_paths`, `keys` and `known_hosts.d` subdirectories (mode `700`). `control_paths` must exist for `ControlMaster` sockets, since ssh won't create it and silently falls back to a full handshake.
- Hosts declared in `${SSH_HOME}/config` and `config.d/*.conf` are offered as completions for `ssh`, `scp`, `rsync` and the like (wildcard patterns are skipped).

#### Agent

- The user unit `conf/home/systemd/user/ssh-agent.service` runs `ssh-agent -D -a %t/ssh-agent.socket`, so the socket always lives at `${XDG_RUNTIME_DIR}/ssh-agent.socket`.
- The `ssh-agent` extension symlinks that unit into `${XDG_CONFIG_HOME}/systemd/user/` and enables it (a real file in the way is kept as `.bak`). The repo copy is the source of truth, so the unit travels and self-heals across machines. After it's first linked, restart the agent or log in again for it to take effect.
- On start, the unit publishes `SSH_AUTH_SOCK` into the systemd and D-Bus session environment (`ExecStartPost`), so graphical and Flatpak apps inherit it without per-app overrides. It's removed again when the agent stops. No `environment.d` drop-in is used.
- Shells that don't descend from the session manager (TTY logins, `flatpak-spawn --host` shells) don't inherit it, so the extension exports `SSH_AUTH_SOCK` itself when the variable is unset and the socket exists.
- Keys are loaded passively: put `AddKeysToAgent yes` under `Host *` in `${SSH_HOME}/config.d/user.conf`, and the first successful use of a key adds it to the agent for the rest of the session.

### Tasks

Planned work is tracked on the [Issues](https://github.com/Keyaku/keyaku-zprofile/issues) page, grouped by milestone.

### Contributing

I'd highly appreciate it if you'd fork this with the intent of making fixes and improvements that benefits every zsh user.
Particular points of improvements will always be:
* Structuring.
* Optimizations
* Code cleanup and refactor.
* Documentation.
* Testing.
