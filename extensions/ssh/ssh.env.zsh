(( ${+commands[ssh]} )) || return

export SSH_HOME=${XDG_CONFIG_HOME}/ssh
[[ -d $HOME/.ssh ]] && xdg-migrate $HOME/.ssh "${SSH_HOME}"

# Create necessary directories. `control_paths` holds ControlMaster sockets:
# ssh won't create it and silently falls back to a full handshake if missing.
# `${^...}` fans the brace list across SSH_HOME; the `(N/)` glob lists only the
# dirs that already exist, and `:|` subtracts those — so mkdir touches just the
# missing set, in one stat pass, no loop. Skips mkdir entirely when all present.
local -a _ssh_dirs=(agent config.d control_paths keys known_hosts.d)
local -a _ssh_want=(${SSH_HOME}/${^_ssh_dirs})
local -a _ssh_have=(${SSH_HOME}/${^_ssh_dirs}(N/))
local -a _ssh_mk=(${_ssh_want:|_ssh_have})
(( $#_ssh_mk )) && mkdir -m 700 $_ssh_mk
unset _ssh_dirs _ssh_want _ssh_have _ssh_mk
