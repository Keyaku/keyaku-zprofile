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
	* All `extensions/` are loaded unconditionally, while `custom/plugins/` depend on which plugins you insert into `plugins`.
	* Every extension contains first lines which serve as guards in case they're not needed to be loaded; for instance, you don't have docker installed, so the `docker` extension will return without doing anything.
	* The above ensure extensions are loaded only if the appropriate conditions are met, minimizing session login times while keeping the environment well equipped.
	* Completion files (`_*`) are not loaded or considered, avoiding `fpath` pollution.
	* They follow the same naming schemes and structure as `plugins`, including the `.plugin.zsh` filename extension.
3. Custom functions under `custom/functions/`.
4. Custom plugins under `custom/plugins/`.
5. Custom plugins under `custom/themes/`.

### Dependencies

Currently, all set git submodules are required for the environment to work correctly. This will be addressed in the future so they become optional.
What this means: _Oh-My-ZSH_, _powerlevel10k_ and _zsh-syntax-highlighting_ are all assumed enabled and loaded by default (provided the setup script is executed without errors).

If you don't like or want these, it's possible to change it after the fact, but this project still isn't quite ready for such scenarios. It's only a matter of time before I make this more adaptable to users' needs.

#### Oh-My-ZSH

This addon is loaded at the usual `zshrc` stage after disabling auto-updates and having gone through any user configuration, in file `zstages/rc/25-omz-load.zsh`.
Its plugin loader was replaced by my own code, which is optimized as much as possible and avoids `fpath` pollution, guaranteeing faster load times than OMZ (based on current tests).

#### Powerlevel10k

This theme is set at the usual `zshrc` stage, before OMZ is loaded, with a code block in `zstages/rc/10-setup.zsh` that loads the cached instant prompt file if it's enabled.
Its folder is symlinked into `custom/themes/`.

#### zsh-syntax-highlighting

This plugin is loaded like any other plugin at the `zshrc` stage, added to `plugins` array in `zstages/rc/20-omz-setup.zsh`.
Its folder is symlinked into `custom/plugins/`.

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
3. Make sure the script sets up everything correctly. It'll keep track of every substep in the file `.first_init` at the root of the git repo.
4. Log out and log back in.


### Customization

Right now, customization is feasible but not yet easy.

#### Plugins, themes, etc.

Currently not possible to configure without OMZ. The idea would be a file in `zstages/rc/` between priorities 10-20, where one would set the plugins, themes, etc.

#### OMZ configuration, plugins, themes

Every OMZ configuration you'd find from their `.zshrc` template happen in `zstages/rc/21-omz-config.zsh`.
This includes setting the plugins or themes. Although you cannot override one of these files yet, you may add a file in `zstages/rc/` with a higher priority (ideally before 25, where OMZ is sourced) to reflect your preferences.


### Tasks

I store a [list of all major tasks](TODO.md) (that I can think of) to improve this setup, on top of the [Issues](issues) page.

### Contributing

I'd highly appreciate it if you'd fork this with the intent of making fixes and improvements that benefits every zsh user.
Particular points of improvements will always be:
* Structuring.
* Optimizations
* Code cleanup and refactor.
* Documentation.
* Testing.
