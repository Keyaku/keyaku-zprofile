# Improvements for this entire project

This tasklist contains all ideas or improvements for this environment setup.

## TODO

### Main profiles (`.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`)

* [ ] Reorganize `.zshenv`, `.zprofile`, `.zshrc`, `.zlogin` to have their intended profiling (and not the currently existing spaghetti).
* [x] Reference to ohmyzsh, either as submodule or cloning it externally. 
* [x] Add external themes and plugins into this repo.
* [ ] Avoid oh-my-zsh's automatic renaming of the current `.zshrc`, or rename it after its installation.
* [ ] Remove redundant checks for `[[ -o login ]]` and/or `[[ -o interactive ]]` in files that are already loaded for that intended purpose.
* [ ] Load configuration for each app from a `profile.d` .zsh script, and streamline which scripts to load on each profile file.
* [ ] Prepare auto-creation of `.dir_colors`.
* [ ] Prepare auto-creation of `.p10k.zsh`, or ask user to set it up.

### `.zfunc/`

* [ ] Write function to initialize this entire environment without manual setup.
* [ ] Rewrite some of the functions from functions.zsh as loadable `fpath` functions, and load them in `.zshrc`.
	* [x] Load from `.zfunc` in `.zshrc`.
	* [x] Rewrite core functions: `command-has`, `env_update`/`env_find`, `get_funcname`.
	* [ ] Rewrite argument tester functions: `is_int`, `is_num`, `is_array`, `is_dict`.
	* [ ] Rewrite print functions: `print_callstack`, `print_error`, `print_warn`, `print_noenv`.


### `profile.d/`

* [ ] Consider rewriting basic functions (e.g. `is_int`) in pure ZSH; this will break compatibility with POSIX and other shells, at the cost of more elegant and scoped code.
This is a repo dedicated to ZSH profiles, not a catch-all solution.
* [ ] Create skeleton for a synchronization software (e.g. SyncThing) to do its thing for multi-platform configuration (SSH, vimrc, etc.).
* [ ] (KDE Plasma) Write function that sets up Window rules (e.g. change the VSCode Flatpak title bar icon from Wayland to VScode).
