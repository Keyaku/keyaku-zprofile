# Improvements for this entire project

This tasklist contains all ideas or improvements for this environment setup.

# TODO

## Repo restructuring

See [STRUCTURE_GOALS](./STRUCTURE_GOALS.md).

## `.zsh` code tasks

### Main profiles (`.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`)

* [ ] Reorganize `.zshenv`, `.zprofile`, `.zshrc`, `.zlogin` to have their intended profiling (and not the currently existing spaghetti). In other words, ensure each file respects their intended `[[ -o login ]]` and/or `[[ -o interactive ]]` behaviors.
	* [ ] `.zshenv`:
		* [ ] This should NOT output, nor modify anything. Just set user environment variables. Also, add all potential paths to `path` array/`PATH` variable (maybe via external file?).
		* [ ] Remove all traces of environment variables for programs that do not come with a new installation (currently targeting Arch Linux with KDE Plasma). Every other envvar should be loaded externally.
	* [ ] `.zprofile` should contain session-wide environment variables and execution.
	* [ ] `.zshrc`:
		* [ ] Remove personal clutter so that it contains the bare minimum for any user to pick up, loading anything else externally.
	* [ ] `.zlogin`:
		* [x] This should be restricted to configuration for a login interactive shell. It should NOT run or make any session-wide changes (read: move `first_init` elsewhere).
		* [ ] Either move anything personal to external files, or add `.zlogin` to `.gitignore`. Preferably the former.
* [ ] Load configuration for each app from a `profile.d` .zsh script (or plugin), and streamline which scripts to load on each profile file.
* [ ] `zupdate`: Improve performance when detecting changes from remote git repo.
* [ ] Fix `.zshrc` recompiling `compdef` when `.zshrc` is read with `-li` or not. Will improve performance. The problem seems to lie in how `$fpath` is aggregated.


### Bug fixes

* [ ] `zsource`: Allow sending parameters with `/` as if indicating relative paths.


### `custom/functions/`

* [ ] Add arguments to `(add|rm|has)path` functions, particularly for verbosity and to return 0 even in case of non-added paths.
* [ ] Create autocomplete for main functions.
* [ ] `zsource`: Allow sourcing any file like with `source`; default prefix to `profile.d`.
* [ ] Write function or code that receives an associative array for formatted "usage" printing, where keys = `shortopt|longopt`, and values = description of associated option.


### `profile.d/`

* [ ] Implement function that fetches system's package manager and installs packages accordingly.
* [ ] Wrap appropriate sections with `[[ -o login ]]`, `[[ -o interactive ]]` and/or `is_sourced_by` so that sourcing one of these files from main profiles sets only the according environment stuff.
* [ ] Initialize password store with existing GPG key (e.g. `pass init GPGKEY`).
* [ ] Create skeleton for a synchronization software (e.g. SyncThing) to do its thing for multi-platform configuration (SSH, vimrc, etc.).
