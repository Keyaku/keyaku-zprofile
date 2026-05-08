@RTK.md

# keyaku-zprofile — ZDOTDIR Configuration

A personal ZSH environment managed as `$ZDOTDIR` (typically `$XDG_CONFIG_HOME/zsh`). This is **ZSH only** — never bash/fish/sh.

## Repository Layout

```
.zshenv / .zprofile / .zshrc / .zlogin / .zlogout   # ZSH startup files (entry points)
lib/core/         # Fundamental utilities, loaded in .zshenv for every shell
lib/interactive/  # Interactive-shell helpers, loaded in .zshrc
lib/login/        # Login-shell helpers
zstages/env/      # Loaded by .zshenv, numbered by priority (00-, 10-, …)
zstages/profile/  # Loaded by .zprofile
zstages/rc/       # Loaded by .zshrc (OMZ loaded at 25-omz-load.zsh)
zstages/login/    # Loaded by .zlogin
extensions/       # Own plugins (unconditionally sourced but self-guard via command checks)
custom/           # User plugins/themes/functions (tracked but empty by default)
vendor/ohmyzsh/   # Git submodule
conf/             # Setup scripts and config files
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
- Do not use `echo` for user-facing messages; use `print_fn`.
- Do not use PCRE regex tokens (`\d`, `\s`, `\w`, `\b`).
