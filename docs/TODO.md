# Improvements for this entire project

This tasklist contains all ideas or improvements for this environment setup.

# TODO

## Repo restructuring

See [STRUCTURE_GOALS](./STRUCTURE_GOALS.md).

## `.zsh` code tasks

### User configuration

At the moment, the setup for this configuration is specifically targeted to my needs, which do not represent the use cases for everyone.
As such, the `first_init.zsh` script should be ammended to prompt the user for their own preferences and set them accordingly, and the `extensions/` to avoid quietly setting things up that might not be aligned to a user's preference.

Essentially:
* [ ] Add prompts for each `setup_*` function in `first_init.zsh`.
* [ ] Avoid quiet operations in `extensions`.
* [ ] Potentially have a global array akin to `plugins` to load selected extensions to load. This might not be necessary since the extensions _usually_ have a first line that checks for context clues (e.g. availability of one or more commands), which bars them to load if not necessary, improving performance. However, some people might not even want their `extensions/` to load for any reason whatsoever, and this must be respected.
* [ ] Make any submodule optional. This requires a bit of work:
	* [ ] Add zsh-style configuration that controls which submodules are enabled or not via `zstyle ':zprofile:submodules:flatpak' enabled no`.
	* [ ] If a submodule is disabled, ensure there is no attempt to load it, whether that is the sourcing of `ohmyzsh` or the selection of `powerlevel10k`.
	* [ ] In the case of `ohmyzsh` being disabled, ensure the environment works without it (by adding the necessary phases, e.g. `compdef` and plugin logic) and that no extension depends on it.

### Main profiles (`.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`)

* [ ] Reorganize `.zshenv`, `.zprofile`, `.zshrc`, `.zlogin` to have their intended profiling (and not the currently existing spaghetti). In other words, ensure each file respects their intended `[[ -o login ]]` and/or `[[ -o interactive ]]` behaviors.
	* [x] `.zshenv`:
		* [x] This should NOT output, ~nor modify anything~ at the very best create missing directories (and even so, this should be reconsidered). Just set user environment variables. Also, add all potential paths to `path` array/`PATH` variable (maybe via external file?).
		* [x] Remove all traces of environment variables for programs that do not come with a new installation (currently targeting Arch Linux with KDE Plasma). Every other envvar should be loaded externally.
	* [x] `.zprofile` should contain session-wide environment variables and execution.
	* [x] `.zshrc`:
		* [x] Remove personal clutter so that it contains the bare minimum for any user to pick up, loading anything else externally.
	* [x] `.zlogin`:
		* [x] This should be restricted to configuration for a login interactive shell. It should NOT run or make any session-wide changes (read: move `first_init` elsewhere).
		* [x] Either move anything personal to external files, or add `.zlogin` to `.gitignore`. Preferably the former.
	* [ ] **Final step**: Move my own user-defined stuff (variables, aliases...) to an untracked directory, or to a separate branch that will be personal to me and won't affect the main branch.
* [x] `zupdate`: Improve performance when detecting changes from remote git repo.
* [x] Create easy way to recompile `lib/core/` manually (which is recompiled on `zupdate` if there are remote changes), or detect that the compiled files are older than the `.zsh` files themselves.
* [ ] Fix `.zshrc` recompiling `compdef` when `.zshrc` is read with `-li` or not. Will improve performance. The problem seems to lie in how `$fpath` is aggregated.


### Bug fixes

All cleaned up! But there'll be more to come.


### `custom/functions/`

* [ ] Add arguments to `(add|rm|has)path` functions, particularly for verbosity and to return 0 even in case of non-added paths.
* [ ] Create autocomplete for main functions.
* [ ] Write function or code that receives an associative array for formatted "usage" printing, where keys = `shortopt|longopt`, and values = description of associated option.


### `zstages/`

* [ ] Implement function that fetches system's package manager and installs packages accordingly.
	* [ ] Potentially use [metapac](https://github.com/ripytide/metapac).
* [ ] Initialize password store with existing GPG key (e.g. `pass init GPGKEY`).
* [ ] Create skeleton for a synchronization software (e.g. SyncThing) to do its thing for multi-platform configuration (SSH, vimrc, etc.).
