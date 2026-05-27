@RTK.md

# keyaku-zprofile — ZDOTDIR Configuration

A personal ZSH environment managed as `$ZDOTDIR` (typically `$XDG_CONFIG_HOME/zsh`). This is **ZSH only** — never bash/fish/sh.

## Repository Layout

```
.zshenv / .zprofile / .zshrc / .zlogin / .zlogout   # ZSH startup files (entry points)
lib/core/         # Fundamental utilities, loaded in .zshenv for every shell
lib/interactive/  # Interactive-shell helpers, loaded in .zshrc
lib/login/        # Login-shell helpers
lib/script/       # Shared helpers for standalone scripts under conf/home/bin/.
                  # NOT auto-loaded by any zstage — scripts source these explicitly.
zstages/env/      # Loaded by .zshenv, numbered by priority (00-, 10-, …)
zstages/profile/  # Loaded by .zprofile
zstages/rc/       # Loaded by .zshrc (OMZ loaded at 25-omz-load.zsh)
zstages/login/    # Loaded by .zlogin
extensions/       # Own plugins (unconditionally sourced but self-guard via command checks)
completions/      # Zsh `_<funcname>` completions for lib/ functions (prepended to $fpath)
custom/           # User plugins/themes/functions (tracked but empty by default)
vendor/ohmyzsh/   # Git submodule
conf/             # Setup scripts and config files
conf/home/bin/    # Standalone zsh scripts symlinked into $HOME/.local/bin/
                  # (e.g. owrt-config.zsh, wol-manager.zsh). Source lib/script/*.zsh.
```

## Key Conventions

### Loading order
`lib/core/` → `zstages/env/` → `lib/login/` → `zstages/profile/` → `lib/interactive/` → `zstages/rc/` → `zstages/login/`

Numbers in filenames control load order within each stage (lower = earlier).

### Core utilities (lib/core/)
- `print_fn` — styled stderr printer with levels `-s/-e/-w/-i/-d`, optional callstack (`-c`), timestamp (`-T`), no-header (`-n`). **Always use this instead of `echo`/`print` for user-facing messages.**
- `check_argc` — validates argument counts; call at the top of functions.
- `is_sourced` / `is_sourced_by` — check if a file is being sourced and by which profile.
- `whatami` — detects OS/distro (Linux, macOS, Android, WSL, Arch, etc.) with caching.
- `addpath` / `rmpath` / `haspath` — manipulate `$path` (ZSH array tied to `$PATH`).
- `addvar` / `rmvar` / `hasvar` — manipulate colon-delimited env vars.
- `command-has` — check for command/function/alias existence with `-a` (AND) / `-o` (OR).

### Script helpers (lib/script/)
Sourced à la carte by standalone scripts under [conf/home/bin/](conf/home/bin/) — never by `.zshenv`/`.zshrc`/zstages. After the script does its `$0` plugin-standard dance and sets `THIS` / `THIS_NAME`, it sources whichever of these it needs:
- [lib/script/bootstrap.zsh](lib/script/bootstrap.zsh) — loads `lib/core` + `lib/interactive` so `print_fn`, `command-has`, `ask` etc. are available; also defines `now` (`date -Iseconds`). Source this first.
- [lib/script/table.zsh](lib/script/table.zsh) — `print_tsv_table` (TSV-in, column-aligned-out).
- [lib/script/config.zsh](lib/script/config.zsh) — `config_value FILE FILTER` and `config_ensure FILE DEFAULT_FN COERCE_FN` for managing `$XDG_CONFIG_HOME/<tool>/config.json`. Caller defines two functions: `DEFAULT_FN` emits the initial JSON (`jq -n …`); `COERCE_FN` reads existing JSON on stdin and emits migrated JSON on stdout (used to backfill new defaults).
- [lib/script/sandbox.zsh](lib/script/sandbox.zsh) — pluggable sandbox detection. `sandbox_list` prints active sandboxes, `sandbox_in [NAME...]` tests (no args = any, with args = membership), `sandbox_run CMD...` executes CMD on the host when sandboxed (e.g. via `flatpak-spawn --host`) or directly otherwise. Add a new sandbox by appending to `SANDBOX_DETECTORS` and defining `_sandbox_detect_<name>` (+ optional `_sandbox_run_<name>`). Flatpak is the only detector shipped today.
- [lib/script/json-store.zsh](lib/script/json-store.zsh) — `jstore_empty`, `jstore_decrypt`, `jstore_encrypt`, `jstore_read`, `jstore_write` for versioned `{version: 1, <key>: […]}` stores, transparently gpg-wrapped when the path ends in `.gpg`. `jstore_read PATH KEY [COERCE_FILTER]` validates shape and applies an optional jq coerce filter for per-record migration; legacy-format migration is the caller's responsibility (use `jstore_decrypt` for the raw read).

**Footgun**: never name a local `path` — it's tied to `$PATH` in zsh and `local path=…` silently destroys PATH inside the function. Prefer `store_path`, `config_path`, `target_dir`, etc. Same caution for `file` (shadows the `file(1)` command).

### Extensions
Each extension in `extensions/` starts with guard lines that `return` early if the relevant tool is not installed — this is intentional and must be preserved. Guards use `command-has` or direct `(( $+commands[...] ))` checks.

### Regex
Use **POSIX ERE** patterns, not PCRE. Termux (Android) `zsh` builds without PCRE support, so patterns like `\d`, `\s`, `\w` will fail with "trailing backslash" or similar errors. Use `[[:digit:]]`, `[[:space:]]`, `[[:alnum:]]` etc. instead. ZSH glob-style patterns (`<->` for integers, `(#b)` groups) are fine in their appropriate contexts.

### Style
- Tabs for indentation (not spaces).
- `zparseopts -D -F -K` for option parsing in every function that accepts flags.
- Usage arrays named `usage`, printed with `>&2 print -l $usage`.
- `local -r`, `local -i`, `local -a`, etc. — use typed locals.
- No ANSI codes by hand; use `${fg_bold[color]}` / `${fg_no_bold[color]}` / `${reset_color}` from `colors`.
- Compiled (`.zwc`) files are gitignored; run `zcompile` or `zupdate` to refresh them.
- Function definition forms carry meaning: `function NAME { … }` for top-level (public) functions, `name() { … }` for nested locals. The completions drift checker uses this distinction.

### Completions (`completions/`)
- One `_<funcname>` file per user-facing function in `lib/core/` and `lib/interactive/` (the checker only scans those two — `lib/login/`, `lib/script/` and `extensions/` are out of scope). Files start with `#compdef NAME` and use `_arguments -s -S`. Style reference: [custom/plugins/owrt-config/_owrt-config](custom/plugins/owrt-config/_owrt-config).
- `completions/.skip` lists `lib/` functions that intentionally have no completion (internal helpers, free-value checkers). Underscore-prefixed names are auto-skipped.
- Drift between `lib/` and `completions/` is caught by [conf/check-completions.zsh](conf/check-completions.zsh) — invoked at the tail of `zupdate` (warn-only) and by the pre-commit hook at [conf/hooks/pre-commit](conf/hooks/pre-commit) (blocking; bypass with `--no-verify`). Hook is enabled by `setup_git_hooks` in `first_init.zsh` via `git config core.hooksPath conf/hooks`. The hook is POSIX sh and re-execs the checker through `flatpak-spawn --host` when `/.flatpak-info` is present, so it works from Flatpak-sandboxed git clients (e.g. VSCode-in-Flatpak).

## Root / Elevated-User Sharing

Root gets a **sparse `ZDOTDIR`** at `${XDG_CONFIG_HOME:-$HOME/.local/config}/zsh`. Code directories are symlinked to this repo (always live); startup entry points are copied (stable, rarely change). Run `setup_root` via `first_init.zsh` to bootstrap this:

```
${XDG_CONFIG_HOME:-$HOME/.local/config}/zsh/
  lib/        → symlink to $ZDOTDIR/lib        (live)
  extensions/ → symlink to $ZDOTDIR/extensions  (live)
  zstages/    → symlink to $ZDOTDIR/zstages     (live)
  vendor/     → symlink to $ZDOTDIR/vendor      (live)
  conf/       → symlink to $ZDOTDIR/conf        (live)
  custom/                                        (own, empty)
  .zshenv / .zprofile / .zshrc / .zlogin / .zlogout   (copied — sync if changed)
```

Because entry points and stage files use `$ZDOTDIR` at runtime (which expands to root's own dir), and `$HOME` for XDG paths, each user's cache, state, and user config (`.p10k.zsh`, etc.) stay fully independent.

### Root hardening (EUID guards)

- **`ZSH_DISABLE_COMPFIX=true`** is set in `20-omz-setup.zsh` when `EUID == 0`, suppressing OMZ's insecure-completion-directory warnings.
- **fastfetch is skipped** (`10-setup.zsh`) — cosmetic, not needed for root.
- Root has no `.p10k.zsh` by default → falls back to the theme set in `21-omz-config.zsh`. The powerlevel10k theme file itself is symlinked into root's `custom/themes/` by `setup_root`, so dropping a `.p10k.zsh` into root's `$ZDOTDIR` is enough to opt in.
- Pattern for new EUID guards: `(( EUID != 0 ))` wrapping the body, or `(( EUID == 0 )) && return` at the top of something that should never run as root.

### Security note

Symlinked code dirs are owned by the repo user. If that user has sudo, the trust level is equivalent — a compromised account already has a path to root. Root's own startup files (`.zshenv` etc.) are root-owned.

## Known Cross-Platform Concern
Code must work on both Arch Linux (primary) and **Termux (Android)**. Termux has a reduced/different zsh build:
- No PCRE regex support → use POSIX ERE character classes only.
- Some system paths differ (`/data/data/com.termux/...`).
- Extensions should self-guard so Termux-unavailable tools are silently skipped.

## Benchmarking / Debug
Set `ZSH_PROFILE_BENCHMARK=1` to time each sourced file. Set `ZSH_PROFILE_DEBUG=1` to enable `XTRACE`. Both are unset by default.

## What NOT to do
- Do not add commands that produce output to `.zshenv` (it's sourced even in non-interactive, non-TTY contexts).
- Do not add personal/private config (API keys, host-specific vars) to tracked files — use `*.local.*` files (gitignored).
- Do not hardcode local paths or usernames — use `$HOME`, `$USER`, `$ZDOTDIR`, `$XDG_CONFIG_HOME`, etc.
- Do not use `echo` for user-facing messages; use `print_fn`.
- Do not use PCRE regex tokens (`\d`, `\s`, `\w`, `\b`).
