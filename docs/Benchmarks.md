# Benchmarks

### Oh-My-Zsh

#### Unmodified `oh-my-zsh.sh`, `plugins=()`

```log
pre-checks took 0.00089907646179199219s
cache & completions directory, check_for_upgrade.sh and adding {functions,completions} to fpath took 0.0018076896667480469s
plugins to fpath and compinit block took 0.027016878128051758s
lib files loop took 0.022481679916381836s
plugins loop took 6.008148193359375e-05s
custom configs loop took 8.9406967163085938e-05s
theme loading and completion colors took 0.0082950592041015625s
[TOTAL] oh-my-zsh.sh took 0.060915470123291016s
```

Heavier blocks:
1. `compinit` block: ~27ms.
2. `lib` files loop: ~22ms.
3. `check_for_upgrade.sh` and `fpath` loop: ~1.8ms.

#### Unmodified `oh-my-zsh.sh`, `plugins=(command-not-found ufw flatpak git pip)`, removed aliases

```log
pre-checks took 0.0010867118835449219s
cache & completions directory, check_for_upgrade.sh and adding {functions,completions} to fpath took 0.0016937255859375s
plugins to fpath and compinit block took 0.030525684356689453s
lib files loop took 0.022714138031005859s
plugins loop took 0.0078566074371337891s
custom configs loop took 0.00011086463928222656s
theme loading and completion colors took 0.0086431503295898438s
[TOTAL] oh-my-zsh.sh took 0.072922945022583008s
```

Heavier blocks:
1. `compinit` block: ~30ms.
2. `lib` files loop: ~23ms.
3. `plugins` loop: ~7ms.
