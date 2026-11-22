# Your own overlay: `$ZDOTDIR/user/`

Copy this directory to `$ZDOTDIR/user/` (gitignored) and keep only what you need. Everything in it is yours: updates to the repo never touch it.

- `settings.zsh` is sourced by `.zshenv` right after `lib/core/`, before every stage: use it for `zext`, `zsubmod` and plain variables such as `ZSH_THEME`.
- `user/<stage>/` (`env`, `profile`, `rc`, `login`, `logout`) is merged into `zstages/<stage>/`: all files are sourced together in filename order, so the number picks where yours runs (e.g. `rc/22-*.zsh` runs after OMZ is configured and before it loads at 25).
- A file with the same name as a tracked one replaces it. `zupdate` warns when the tracked file you replaced changes upstream, so you can merge the changes in.

To share it between machines, `first_init.zsh` can register it with Syncthing as folder `zsh-user` (see "Syncing between machines" in the README), or `user/` can be a symlink into any synced folder. Root's sparse ZDOTDIR has its own `user/`.
