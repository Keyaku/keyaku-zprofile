# Keyaku's ZDOTDIR configuration

A whole set of profile and utilities to improve my daily use of ZSH.

## Description

**NOTE**: This is an environment for **ZSH** _only_. Most of these will not work in `bash`, and won't work **AT ALL** with `fish`.

### Summary

This is a comprehensive list of profile files, loaded at boot, login or interactive shell, filled with auxiliary functions and lifesavers.
This is not to replace anyone's current profile configuration; this is my own, riddled with issues and spaghetti that I try to improve every once in a while.
If any of the functions I introduce is already reproducible via some POSIX shell or ZSH substitution, sometimes even more elegantly or better in performance,
it's very likely that I am not aware of it, or haven't yet updated the function to reflect that.

I'm always willing to learn new tricks; I just haven't researched them all.

### Scope

The intent is to write functions, aliases and environment variables to:
- Have lifesavers to be used via command line, or to avoid boilerplate in scripts. 
- Prepare the appropriate environment for each installed program (e.g. `GNUPGHOME`).
- Have an initialization code block which makes the specific setups to my liking for any new Linux distro installation.
- Attempt to clear the `$HOME` directory from dotfiles as much as possible, so it contains the bare minimum.
One very quick way to check is with the following command:
```zsh
echo $HOME/.*(:s,$HOME/,,)
```
The lower the number of these files, the better organized is my setup. This is, unfortunately, easier said than done due to principally developers not having adopted the XDG directory specification, or having implemented it poorly (by forcing a path instead of reading it from the environment).
For more info on each entry, I use [xdg-ninja](https://github.com/b3nj5m1n/xdg-ninja).

### Contents

This repo contains the fundamental profile files which allow me to use my Unix/Linux system with as little hassle as possible.  
These are:
- [ZSH startup profiles](https://wiki.archlinux.org/title/Zsh#Startup/Shutdown_files) under `$ZDOTDIR/`, sorted in order which they are loaded:
	1. `.zshenv` - Used for setting user's environment variables; it should not contain commands that produce output or assume the shell is attached to a TTY. When this file exists it will **_always_** be read.
	2. `.zprofile` - Used for executing user's commands at start, will be read when starting as a **_login shell_**. Typically used to autostart graphical sessions and to set session-wide environment variables.
	3. `.zshrc` - Used for setting user's interactive shell configuration and executing commands, will be read when starting as an **_interactive shell_**.
	4. `.zlogin` - Used for executing user's commands at ending of initial progress, will be read when starting as a **_login shell_**. Typically used to autostart command line utilities. Should not be used to autostart graphical sessions, as at this point the session might contain configuration meant only for an interactive shell.
- Custom functions under `.zfunc/` (WORK IN PROGRESS).
- Various .zsh scripts under `profile.d/`, containing everything from base functionality that helps one's everyday use, down to setting up the environment of an app or program, or even of a specific OS.


## Practicality

### How to use this

Why would you want to?

If you insist, do the following:
1. Download the ZIP.
2. Extract its contents to `$XDG_CONFIG_HOME/zsh`, so that all dotfiles (e.g. `.zshenv`) stay at the root of that directory.
3. The rest of the setup is currently manual, though I am working in a one-click solution.
Essentially, add the line `export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh` to the default `zshenv` of your system (usually located at `/etc/zsh/zshenv`).
4. Reboot your system.

I really don't recommend cloning the repo if you want to have these for yourself; you'll have a storage wasting `.git` directory in your `$ZDOTDIR`, and in case you accidentally pull any remote changes, they'll be overwriting any of your own.
The best you can do is fork it, then rename your your setup so it reflects _your_ configuration.

However, it would very nice and helpful if you'd fork this with the intent of making fixes or improvements to push via Pull Requests; I'd be extremely thankful, especially if those modifications end up being useful for everyone.

### Tasks

I store a [list of all tasks](TODO.md) (that I can think of) to improve this setup.
This thing is one of those projects that will essentially _never_ end, until I migrate to a newer or better shell. And I'm fine with that.

In case you're wondering: **No**, I'm not moving to `fish`. It's cool, but I don't like it (yet).
