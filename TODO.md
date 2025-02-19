# Improvements for this entire project

This tasklist contains all ideas or improvements for this environment setup.

## TODO

### Main profiles (`.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`)

* [ ] Reorganize `.zshenv`, `.zprofile`, `.zshrc`, `.zlogin` to have their intended profiling (and not the currently existing spaghetti). In other words, ensure each file respects their intended `[[ -o login ]]` and/or `[[ -o interactive ]]` behaviors.
	* [ ] `.zshenv` should NOT output, nor modify anything. Just set user environment variables.
	* [ ] `.zprofile` should contain session-wide environment variables and execution.
	* [ ] `.zshrc` should load plugins, functions, aliases, completions and all interactive elements. It should NOT set any environment variable other than for ZSH loading purposes.
	* [ ] `.zlogin` should be restricted to configuration for a login interactive shell. It should NOT run or make any session-wide changes (read: move `first_init` elsewhere).
* [x] Reference to ohmyzsh, either as submodule or cloning it externally. 
* [x] Add external themes and plugins into this repo.
* [x] Avoid oh-my-zsh's automatic renaming of the current `.zshrc`, or rename it after its installation.
* [x] Remove redundant checks for `[[ -o login ]]` and/or `[[ -o interactive ]]` in files that are already loaded for that intended purpose.
* [ ] Load configuration for each app from a `profile.d` .zsh script, and streamline which scripts to load on each profile file.
* [ ] Prepare auto-creation of `.dir_colors`.
* [x] Prepare auto-creation of `.p10k.zsh`, or ask user to set it up.
* [ ] `zprofile-update`: Improve performance when detecting changes from remote git repo.
* [ ] Fix `print_invalidarg`'s erroneous argument format. E.g.: `Invalid argument: ''path' is not an array'` should be something like `parent_funcname: 'path' is not an array`.
* [x] Change `print_invalidarg`'s format to: `funcname:lineno: `. Apply the same in other printing cases.
* [x] Add first setup code to point `ZDOTDIR` to this directory in the system's `zshenv`.


### Bug fixes

* [x] Fix `haspath: command not found...` occurring in certain cases.
* [x] **Termux**: Find solution for Termux to avoid `rsync` changes between Termux and device storage; or at the very least avoid p10k's instant prompt warning for printing output while it loads.
* [x] **Termux**: Fix error at start of `Invalid argument: ''path' is not an array'`.


### `.zfunc/`

* [x] Write function to initialize this entire environment without manual setup.
* [ ] Rewrite some of the functions from functions.zsh as loadable `fpath` functions, and load them in `.zshrc`.
	* [x] Load from `.zfunc` in `.zshrc`.
	* [x] Rewrite core functions: `command-has`, `env_update`/`env_find`, `get_funcname`.
	* [ ] Rewrite argument tester functions: `is_int`, `is_num`, `is_array`, `is_dict`.
	* [x] Rewrite print functions: `print_callstack`, `print_error`, `print_warn`, `print_noenv`.
* Add arguments to `(add|rm|has)path` functions, particularly for verbosity and to return 0 even in case of non-added paths.


### `profile.d/`

* [ ] Consider rewriting basic functions (e.g. `is_int`) in pure ZSH; this will break compatibility with POSIX and other shells, at the cost of more elegant and scoped code.
This is a repo dedicated to ZSH profiles, not a catch-all solution.
* [ ] Create skeleton for a synchronization software (e.g. SyncThing) to do its thing for multi-platform configuration (SSH, vimrc, etc.).
* [ ] (KDE Plasma) Write function that sets up Window rules (e.g. change the VSCode Flatpak title bar icon from Wayland to VScode).
