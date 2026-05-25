# Improvements for this entire project

This tasklist contains all ideas or improvements for this environment setup.

# TODO

## `.zsh` code tasks

### User configuration

At the moment, the setup for this configuration is specifically targeted to my needs, which do not represent the use cases for everyone.
As such, the `first_init.zsh` script should be ammended to prompt the user for their own preferences and set them accordingly, and the `extensions/` to avoid quietly setting things up that might not be aligned to a user's preference.

Essentially:
* [ ] Add prompts for each `setup_*` function in `first_init.zsh`.
* [ ] Avoid quiet operations in `extensions`.
* [ ] Potentially have a global array akin to `plugins` to load selected extensions. This might not be necessary since the extensions _usually_ have a first line that checks for context clues (e.g. availability of one or more commands), which bars them to load if not necessary, improving performance. However, some people might not even want their `extensions/` to load for any reason whatsoever, and this must be respected.
* [x] Alternative to `_omz_source` without the huge overhead.
* [ ] Make any submodule optional. This requires a bit of work:
	* [ ] Add zsh-style configuration that controls which submodules are enabled or not via `zstyle ':zprofile:submodules:flatpak' enabled no`.
	* [ ] If a submodule is disabled, ensure there is no attempt to load it, whether that is the sourcing of `ohmyzsh` or the selection of `powerlevel10k`.
	* [ ] In the case of `ohmyzsh` being disabled, ensure the environment works without it (by adding the necessary phases, e.g. `compdef` and plugin logic) and that no extension depends on it.
* [ ] Make checks for git submodules on initialization, enabling them only if necessary (e.g. distro comes with zsh-syntax-highlighter installed => disable submodule).

### Main profiles (`.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`)

* [x] Reorganize `.zshenv`, `.zprofile`, `.zshrc`, `.zlogin` to have their intended profiling (and not the currently existing spaghetti). In other words, ensure each file respects their intended `[[ -o login ]]` and/or `[[ -o interactive ]]` behaviors.
	* [x] `.zshenv`:
		* [x] This should NOT output, ~nor modify anything~ at the very best create missing directories (and even so, this should be reconsidered). Just set user environment variables. Also, add all potential paths to `path` array/`PATH` variable (maybe via external file?).
		* [x] Remove all traces of environment variables for programs that do not come with a new installation (currently targeting Arch Linux with KDE Plasma). Every other envvar should be loaded externally.
	* [x] `.zprofile` should contain session-wide environment variables and execution.
	* [x] `.zshrc`:
		* [x] Remove personal clutter so that it contains the bare minimum for any user to pick up, loading anything else externally.
	* [x] `.zlogin`:
		* [x] This should be restricted to configuration for a login interactive shell. It should NOT run or make any session-wide changes (read: move `first_init` elsewhere).
		* [x] Either move anything personal to external files, or add `.zlogin` to `.gitignore`. Preferably the former.
* [x] `zupdate`: Improve performance when detecting changes from remote git repo.
* [x] Create easy way to recompile `lib/core/` manually (which is recompiled on `zupdate` if there are remote changes), or detect that the compiled files are older than the `.zsh` files themselves.
* [x] Fix `.zshrc` recompiling `compdef` when `.zshrc` is read with `-li` or not. Will improve performance. The problem seems to lie in how `$fpath` is aggregated.
* [ ] Move my own user-defined stuff (variables, aliases...) to an untracked directory, or to a separate branch that will be personal to me and won't affect the main branch.


### Bug fixes

All cleaned up! But there'll be more to come.


### `lib/`

* [x] Create autocomplete for main functions.
* [ ] Implement function that fetches system's package manager and installs packages accordingly.
	* [ ] Potentially use [metapac](https://github.com/ripytide/metapac).
* [ ] Check if `[[ -t 1 ]]` is applicable in this environment.


### `zstages/`

* [ ] Initialize password store with existing GPG key (e.g. `pass init GPGKEY`).
* [ ] Create skeleton for a synchronization software (e.g. SyncThing) to do its thing for multi-platform configuration (SSH, vimrc, etc.).


### SSH agent

Background: the user-level `ssh-agent.service` (`conf/home/systemd/user/ssh-agent.service`, symlinked into `${XDG_CONFIG_HOME}/systemd/user/` by `extensions/ssh-agent`) runs `/usr/bin/ssh-agent -D -a %t/ssh-agent.socket`, so the socket sits at the deterministic path `${XDG_RUNTIME_DIR}/ssh-agent.socket`. The unit also publishes `SSH_AUTH_SOCK` into the systemd/D-Bus session environment via `ExecStartPost`, so graphical and Flatpak sessions inherit it. Shells that don't descend from the session manager (plain TTY logins, `--host` shells) won't, so zsh exports it itself from the known socket path.

* [x] Export `SSH_AUTH_SOCK` to the session environment so graphical/Flatpak apps inherit it without per-app overrides — handled by the service's `ExecStartPost` (`systemctl --user set-environment` + `dbus-update-activation-environment`), deliberately avoiding any `environment.d` drop-in.
* [x] Export `SSH_AUTH_SOCK` to zsh for shells that don't inherit the session environment (TTY, `--host`): the `ssh-agent` extension sets it from `${XDG_RUNTIME_DIR}/ssh-agent.socket` when the socket exists and the variable is unset.
* [x] Auto-load keys into the agent so connections don't need a manual `ssh-add` each session: `AddKeysToAgent yes` (`${XDG_CONFIG_HOME}/ssh/config.d/user.conf`, under `Host *`) seeds the agent passively on any successful key use — works for every key, no extra unit.
	* [ ] Optional, more proactive alternative: a oneshot `ssh-add.service` (`Wants=`/`After=ssh-agent.service`) that pre-loads selected passphrase-less keys at agent start. Encrypted keys would block it unless paired with a `pinentry` agent, so only worth adding if pre-seeding specific keys before first use is actually needed.
* [ ] Document the agent setup in `docs/README.md` (no SSH/XDG section exists yet — would be a new one).
