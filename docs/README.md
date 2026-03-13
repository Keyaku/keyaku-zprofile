# Keyaku's ZDOTDIR configuration

A whole set of profile and utilities to improve my daily use of ZSH.

## Description

**NOTE**: This is an environment for **ZSH** _only_. Most of these will not work in `bash`, and won't work **AT ALL** with `fish`.

### Summary

This is a comprehensive list of profile files, loaded at boot, login or interactive shell, filled with auxiliary functions and lifesavers.
Currently, it's not meant to replace anyone's current profile configuration, although it is going to be the case as soon as I make it flexible to anybody who wishes to make use of the myriad of functions I wrote.
If any of the functions I introduce is already reproducible via some POSIX shell or ZSH substitution, sometimes even more elegantly or better in performance,
it's very likely that I am not aware of it, or haven't yet updated the function to reflect that.

I'm always willing to learn new tricks; I just haven't researched them all.

### Scope

The intent is to have functions, aliases and environment variables to:
- Have lifesavers to be used via command line, and/or to avoid boilerplate in scripts. 
- Prepare the appropriate environment for each installed program (e.g. set `GNUPGHOME` for `gnupg`).
- Have an initialization code block which makes the specific setups for any new Linux distro installation.
- Attempt to clear the `$HOME` directory from dotfiles as much as possible, so it contains the bare minimum.
In case you'd like to find out which dotfiles currently sit in your home directory, one very quick way is with the following command:
```zsh
echo $HOME/.*(:s,$HOME/,,)
```
The lower the number of these files, the better organized is my setup. This is, unfortunately, easier said than done due to principally developers not having adopted the XDG directory specification, or having implemented it poorly (by forcing a path instead of reading it from the environment).
For more info on each entry, I use [xdg-ninja](https://github.com/b3nj5m1n/xdg-ninja).

### Contents

This repo contains the fundamental profile files which allow me to use my Unix/Linux system with as little hassle as possible.  
It's structured as follows:
1. [ZSH startup profiles](https://wiki.archlinux.org/title/Zsh#Startup/Shutdown_files) under `$ZDOTDIR/`, sorted in order which they are loaded:
	1. `.zshenv` - Used for setting user's environment variables; it should not contain commands that produce output or assume the shell is attached to a TTY. When this file exists it will **_always_** be read.
	2. `.zprofile` - Used for executing user's commands at start, will be read when starting as a **_login shell_**. Typically used to autostart graphical sessions and to set session-wide environment variables.
	3. `.zshrc` - Used for setting user's interactive shell configuration and executing commands, will be read when starting as an **_interactive shell_**.
	4. `.zlogin` - Used for executing user's commands at ending of initial progress, will be read when starting as a **_login shell_**. Typically used to autostart command line utilities. Should not be used to autostart graphical sessions, as at this point the session might contain configuration meant only for an interactive shell.
2. Custom functions under `.custom/functions/`.
3. Various .zsh scripts under `profile.d/`, containing everything from base functionality that helps one's everyday use, down to setting up the environment of an app or program, or even of a specific OS.
4. My own set of plugins, named `extensions` to differentiate from custom plugins, under `extensions/`. The main difference between this and putting them in `custom/plugins/` is that they're loaded natively with `source` in order to avoid using ohmyzsh's `_omz_source` with its massive overhead, consequently making login shells start as fast as possible.
These follow the same structure as `plugins`, including the `.plugin.zsh` filename extension; `.ext.zsh` is also accepted.


## Practicality

### How to use this

Since my main objectives haven't been achieved yet, I don't recommend it just yet;  
However, if you wish to adopt it now, the procedure is a bit straightforward (with plans to make it much easier in the future). The following presumes `$XDG_CONFIG_HOME` is set to `$HOME/.local/config`, though I plan making it flexible to any other path _except `$HOME/.config`_, since one major point is to clear the home directory from dotfiles: 

1. In a terminal session, go to `$XDG_CONFIG_HOME` and clone this repository to a directory named `zsh`:
```shell
cd "${XDG_CONFIG_HOME:-$HOME/.local/config}"
git clone https://github.com/Keyaku/keyaku-zprofile zsh
```
2. Run the initial setup script:
```shell
"${XDG_CONFIG_HOME:-$HOME/.local/config}"/zsh/conf/first_setup.zsh
```
3. Make sure the script sets up everything correctly. It'll keep track of every substep in the file `.first_init` at the root of the git repo.
4. Reboot your system.

Right now, customization is not possible, though it is intended.
In case you need to customize it to fit your needs, the best you can do is fork it.

In addition, it would very nice and helpful if you'd fork this with the intent of making fixes and improvements to push via Pull Requests; I'd be extremely thankful, especially if those modifications end up being useful for everyone.

### Tasks

I store a [list of all major tasks](TODO.md) (that I can think of) to improve this setup.
This thing is one of those projects that will essentially _never_ end, until I migrate to a newer or better shell. And I'm fine with that.

In case you're wondering: **No**, I'm not moving to `fish`. It's cool, but I don't like it (yet).
