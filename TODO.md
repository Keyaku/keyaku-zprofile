# Improvements for this entire project

This tasklist contains all ideas or improvements for this environment setup.

## TODO

### Main profiles (`.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`)

* [ ] Reorganize `.zshenv`, `.zprofile`, `.zshrc`, `.zlogin` to have their intended profiling (and not the currently existing spaghetti). In other words, ensure each file respects their intended `[[ -o login ]]` and/or `[[ -o interactive ]]` behaviors.
	* [ ] `.zshenv`:
		* [ ] This should NOT output, nor modify anything. Just set user environment variables. Also, add all potential paths to `path` array/`PATH` variable (maybe via external file?).
		* [ ] Remove all traces of environment variables for programs that do not come with a new installation (currently targeting Arch Linux with KDE Plasma). Every other envvar should be loaded externally.
	* [ ] `.zprofile` should contain session-wide environment variables and execution.
	* [ ] `.zshrc`:
		* [x] Should load plugins, functions, aliases, completions and all interactive elements. It should NOT set any environment variable other than for ZSH loading purposes.
		* [ ] Remove personal clutter so that it contains the bare minimum for any user to pick up, loading anything else externally.
	* [ ] `.zlogin`:
		* [x] This should be restricted to configuration for a login interactive shell. It should NOT run or make any session-wide changes (read: move `first_init` elsewhere).
		* [ ] Either move anything personal to external files, or add `.zlogin` to `.gitignore`. Preferably the former.
* [x] Reference to ohmyzsh, either as submodule or cloning it externally. 
* [x] Add external themes and plugins into this repo.
* [x] Avoid oh-my-zsh's automatic renaming of the current `.zshrc`, or rename it after its installation.
* [x] Remove redundant checks for `[[ -o login ]]` and/or `[[ -o interactive ]]` in files that are already loaded for that intended purpose.
* [ ] Load configuration for each app from a `profile.d` .zsh script (or plugin), and streamline which scripts to load on each profile file.
* [x] Prepare auto-creation of `.p10k.zsh`, or ask user to set it up.
* [ ] `zupdate`: Improve performance when detecting changes from remote git repo.
* [x] Add first setup code to point `ZDOTDIR` to this directory in the system's `zshenv`.
* [x] Make sure `zsh` is loadable without `login` (`-l`) or `interactive` (`-i`) by either loading required functions accordingly, or avoid the use of these functions altogether. Gearing towards the former.
* [ ] Fix `.zshrc` recompiling `compdef` when `.zshrc` is read with `-li` or not. Will improve performance. The problem seems to lie in how `$fpath` is aggregated.


### Bug fixes

* [x] Fix `haspath: command not found...` occurring in certain cases.
* [x] **Termux**: Find solution for Termux to avoid `rsync` changes between Termux and device storage; or at the very least avoid p10k's instant prompt warning for printing output while it loads.
* [x] **Termux**: Fix error at start of `Invalid argument: ''path' is not an array'`.
* [ ] `zsource`: Allow sending parameters with `/` as if indicating relative paths.


### `custom/functions/`

* [x] Write function to initialize this entire environment without manual setup.
* [x] Rewrite some of the functions from `functions.zsh` as loadable `fpath` functions, and load them in `.zshrc`.
	* [x] Load from `custom/functions/` in `.zshrc`.
	* [x] Rewrite core functions: `command-has`, `env_update`/`env_find`, `get_funcname`.
	* [x] Rewrite print functions: `print_callstack`, `print_error`, `print_warn`.
* [ ] Add arguments to `(add|rm|has)path` functions, particularly for verbosity and to return 0 even in case of non-added paths.
* [ ] Create autocomplete for main functions.
* [x] `zsource`: Add flags for sourcing login (-l|--login) and interactive (-i|--interactive) files.
* [ ] `zsource`: Allow sourcing any file like with `source`; default prefix to `profile.d`.
* [ ] Write function or code that receives an associative array for formatted "usage" printing, where keys = `shortopt|longopt`, and values = description of associated option.


### `profile.d/`

* [x] Make core functions stop execution if an error occurred.
* [x] Fix SSH configuration so that it meets the following criteria:
	* [x] Sets up configuration without user prompt (also remove the message to delete `~/.ssh`).
	* [x] Autocompletion works in Terminal.
	* [x] VScode Flatpak finds configured hosts, and is able to connect to them.
	* [x] Git config should follow the new SSH path.
* [ ] Implement function that fetches system's package manager and installs packages accordingly.
* [ ] Wrap appropriate sections with `[[ -o login ]]`, `[[ -o interactive ]]` and/or `is_sourced_by` so that sourcing one of these files from main profiles sets only the according environment stuff.
* [ ] Initialize password store with existing GPG key (e.g. `pass init GPGKEY`).
* [ ] Create skeleton for a synchronization software (e.g. SyncThing) to do its thing for multi-platform configuration (SSH, vimrc, etc.).
* [ ] (KDE Plasma) Write function that sets up Window rules (e.g. change the VSCode Flatpak title bar icon from Wayland to VScode).


### `custom/plugins`

* [x] Consider porting some of the `.zsh` from `profile.d` over to `custom/plugins`.
