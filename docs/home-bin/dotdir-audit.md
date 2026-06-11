# dotdir-audit

Finds the rogue programs that ignore the XDG spec and write straight into the literal dotdirs this repo keeps as symlinks into `.local/`. It does this with the kernel audit subsystem (`auditctl`/`ausearch`), because `fatrace` is unusable on btrfs.

This is an **experimental** script + service combo. It is deliberately *not* wired into `setup_systemd`, so you have to install the bits below by hand before the service will run.

## Watched dotdirs

`.cache`, `.config`, `.pki`

Defined by `WATCH_NAMES` near the top of `dotdir-audit.zsh` — edit that array to change the set. Every name is tested in each real login home (see below).

## Prerequisites

- The `audit` package (`auditctl`, `ausearch`). Install with `sudo pacman -S audit`.
- The runner exposed at the path the unit expects. The service's `ExecStart` points at `/usr/local/bin/dotdir-audit.zsh`, so symlink it:
```sh
sudo ln -s "$ZDOTDIR/conf/home/bin/dotdir-audit.zsh" /usr/local/bin/dotdir-audit.zsh
```

- The unit file in place. It ships under `conf/etc/systemd/system/dotdir-audit.service`:
```sh
sudo cp "$ZDOTDIR/conf/etc/systemd/system/dotdir-audit.service" /etc/systemd/system/
sudo systemctl daemon-reload
```

## How it works (read this first)

The service is `Type=oneshot` + `RemainAfterExit`: starting it runs `dotdir-audit start` (installs the audit watches), stopping it runs `dotdir-audit stop` (removes them). The watches themselves are what log; the report is read separately, at any time.

This is a **recreation test, and it only watches dotdirs that are absent.** Remove a dotdir's symlink first; then `start` drops an empty, owner-matched placeholder there and watches *that*. When a rogue program ignores `XDG_*` and repopulates the literal `~/.<name>`, the first write into the placeholder logs its process name, executable and PID — the answer to "can I delete this symlink?".

Only **symlinks** are skipped (`start` warns and moves on) — a live XDG symlink like `.cache -> .local/config` would make `-w` compile to a recursive `-F dir=` rule (`auditctl(8)` deprecates that form for "poor performance") over the managed target tree, flooding auditd with very high CPU and dropped events. That is why you remove the symlink before testing.

A path that is already a **real directory** — the placeholder from a previous `start`, possibly repopulated by the culprit, or a dir a rogue program created — is watched **as-is**. This is deliberate: it means a `disable`/`enable` cycle (e.g. to also test another dotdir) keeps watching the ones you were already testing, instead of silently dropping them. Caveat: if such a dir is repopulated by a *high-frequency* writer (the Mesa shader cache in `.cache` is the known example), expect elevated audit volume while it stays watched — identify the culprit and stop.

It is host-wide: every real login home (`getent passwd`, uid 0 or ≥1000) is covered, not just your account; service dirs like `/home/linuxbrew` are skipped.

### Timing — when does the watch have to be in place?

A watch only logs events that happen *after* `start` runs. So a manual `start` after you've logged in **will miss anything that gets created at login or at boot** — and several of these dotdirs are recreated exactly then.

To catch login/boot-time offenders, the watch must already exist when they fire, which means `start` has to run before login — i.e. **`enable` the service** so it installs the watches at boot (it orders `After=auditd`). This is cheap now: the placeholder design only fires on writes into an empty dir, so leaving it enabled does *not* reproduce the old recursive-watch CPU storm.

So: `enable` it while hunting login/boot offenders; for an offender you can trigger by hand (launching a specific app), a one-shot `start` is enough. Either way, `disable`/`stop` and restore the symlinks once the hunt is done.

## Typical session — hunting what recreates a dotdir

1. Remove the symlink you want to test (do this for one at a time so the culprit is unambiguous):

```sh
rm ~/.pki
```

2. Enable + start the service. `enable` is what makes the watch land at boot, so login/reboot-time offenders are caught too (use plain `start` only if you'll trigger the offender by hand this session):

```sh
sudo systemctl enable --now dotdir-audit.service
```

3. Use the machine normally for a while — log in/out, reboot, launch the apps you suspect.

4. Read who has hit a watched path:

```sh
sudo dotdir-audit.zsh report
```

Output is one line per `(process, path)`, e.g.:

```
TIME                   PROCESS            EXE                          PATH
11/06/2026 17:30:37.742 chromium           /usr/lib/chromium/chromium   /home/antion/.pki
```

5. Disable + stop when done, remove the empty placeholder `start` created, then restore the symlink:

```sh
sudo systemctl disable --now dotdir-audit.service
rmdir ~/.pki                            # the placeholder (empty unless something repopulated it)
ln -s "$HOME/.local/share/pki" ~/.pki   # whatever the original symlink was
```

## Running it manually (no service)

The service is just a thin wrapper; you can drive the script directly:

```sh
sudo dotdir-audit.zsh start     # install watches
sudo dotdir-audit.zsh report    # read captured events
sudo dotdir-audit.zsh stop      # remove watches
```

## Notes

- Captured events live in the audit log (`ausearch` reads it), so `report` works across reboots and after `stop` — until the audit log rotates. Re-running `start` is harmless.
- A `Could not watch: <path>` warning on `start` usually means an identical rule already exists (e.g. from a prior run) — benign.
- Restore every symlink you removed once you are done; several of these dotdirs (`.config`, `.cache`) are load-bearing for apps that hardcode the literal path.
