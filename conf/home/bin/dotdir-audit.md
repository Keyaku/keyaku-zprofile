# dotdir-audit

Finds the rogue programs that ignore the XDG spec and write straight into `~/.cache`, `~/.config`, `~/.pki` — the dotdirs this repo keeps as symlinks into `.local/`. It does this with the kernel audit subsystem (`auditctl`/`ausearch`), because `fatrace` is unusable on btrfs.

This is an **experimental** script + service combo. It is deliberately *not* wired into `setup_systemd`, so you have to install the bits below by hand before the service will run.

## Prerequisites

- The `audit` package (`auditctl`, `ausearch`). Install with `sudo pacman -S audit`.
- The runner exposed at the path the unit expects. The service's `ExecStart` points at `/usr/local/bin/dotdir-audit.zsh`, so symlink it:

```sh
sudo ln -sfn "$ZDOTDIR/conf/home/bin/dotdir-audit.zsh" /usr/local/bin/dotdir-audit.zsh
```

- The unit file in place. It ships under `conf/etc/systemd/system/dotdir-audit.service`; `setup_systemd` rsyncs `conf/etc/systemd/` into `/etc/systemd`, or copy it yourself:

```sh
sudo cp "$ZDOTDIR/conf/etc/systemd/system/dotdir-audit.service" /etc/systemd/system/
sudo systemctl daemon-reload
```

## How it works (read this first)

The service is `Type=oneshot` + `RemainAfterExit`: starting it runs `dotdir-audit start` (installs the audit watches), stopping it runs `dotdir-audit stop` (removes them). The watches themselves are what log; the report is read separately, at any time.

There are two modes, and which one you get depends on whether the dotdir currently exists:

- **Use mode (symlink present).** While `~/.config` is still a symlink, the watch resolves to its target inode (`.local/config`), so events show up as `.local/...` and are filtered out of the report. You learn who *uses* the data, not who hits the literal dotdir. Low signal for the cleanup question.
- **Recreate mode (symlink removed).** Remove the symlink first. With the literal path absent, `start` watches the *parent* home dir instead, so whatever recreates `~/.config` is logged with its process name, executable and PID. This is the mode that answers "can I delete this symlink?".

It is host-wide: every `/home/*/.{cache,config,pki}` plus root's, not just your account.

## Typical session — hunting what recreates a dotdir

1. Remove the symlink you want to test (do this for one at a time so the culprit is unambiguous):

```sh
rm ~/.pki
```

2. Enable and start the service (this installs the watches now, and again on every boot until you disable it):

```sh
sudo systemctl enable --now dotdir-audit.service
```

3. Use the machine normally for a while — log in/out, launch the apps you suspect, reboot if you want boot-time offenders.

4. Read who has hit a watched path:

```sh
sudo dotdir-audit.zsh report
```

Output is one line per `(process, path)`, e.g.:

```
TIME                   PROCESS            EXE                          PATH
11/06/2026 17:30:37.742 chromium           /usr/lib/chromium/chromium   /home/antion/.pki
```

5. Stop and disable when done, then restore the symlink:

```sh
sudo systemctl disable --now dotdir-audit.service
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
