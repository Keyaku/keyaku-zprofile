# ssh plugin (custom)

A rewrite of ohmyzsh's ssh plugin, adapted to use a different location for `.ssh`

To use it, add `ssh` to the plugins array in your zshrc file:

```zsh
plugins=(... ssh)
```

## Functions

- `ssh_rmhkey`: remove host key from known hosts based on a host section name from `.ssh/config`.
- `ssh_load_key`: load SSH key into agent.
- `ssh_unload_key`: remove SSH key from agent.
