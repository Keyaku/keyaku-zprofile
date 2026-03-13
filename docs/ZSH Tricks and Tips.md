# ZSH Tricks & Tips

## Benchmarking and debugging

Other than enabling `ZSH_PROFILE_BENCHMARK` and `ZSH_PROFILE_DEBUG` in `$ZDOTDIR/.zshenv` (or `/etc/zsh/zshenv`), here are some other tips to help debug ZSH profile loading:

### Loaded sources, modules, functions, etc.

Here are a few ways to check for sources loaded by ZSH at load time:

* `echo $-`: This will print every flag loaded with ZSH.
* `zsh -o SOURCE_TRACE`: This will print each file as it is sourced during startup, showing the full loading sequence.
* * `: | zsh -o SOURCE_TRACE`: This will print every file during startup _without_ login or interactive options.
* `zsh -x`: This sets `xtrace`, which will print all the commands executed, including those that are sourced. Running this alone is not recommended, as it can be very verbose. Instead, do one of combinations below:
* * `zsh -x --no-rcs`: This will disable loading any user z-stage files (`.zshenv`, `.zprofile` etc).
* * `zsh -x --no-rcs --no-functions`: This will also disable loading of functions.
* `zmodload -L`: This will do a runtime check of currently loaded modules.
* `whence -v -- ${(ko)ZSH_ITEM}`: This will list all the currently defined items, where `ZSH_ITEM` is one of the following (non-exhaustive list):
* * `aliases`: aliases.
* * `builtins`: builtin commands.
* * `commands`: commands.
* * `functions`: functions.
* * `options`: options.
* * `parameters`: parameters.
* * `path`: paths in `$PATH` variable.
* * `widgets`: widgets.
