# Select exclusively Debian or Ubuntu (or Termux)
whatami Debian Ubuntu Android || return

(( ${+commands[apt]} || ${+commands[apt-get]} )) || return

# On Termux pacman builds, apt may linger but is not the active manager —
# the pacman db directory is the authoritative signal.
[[ -d "${TERMUX__PREFIX:-}/var/lib/pacman/local" ]] && return

local SUDO=$(whatami Android || echo "sudo ")

### APT-related aliases
alias apt-update="${SUDO}apt update"
alias apt-upgrade="${SUDO}apt upgrade -y --auto-remove"
alias apt-install="${SUDO}apt install --auto-remove"
alias apt-remove="${SUDO}apt remove --auto-remove"
alias apt-purge="apt-remove --purge"
alias apt-autoremove="${SUDO}apt autoremove --purge"
alias apt-all="apt-update && apt-upgrade"
alias apt-clean="${SUDO}apt-get clean"
alias apt-markauto="${SUDO}apt-mark auto"
alias apt-search="apt-cache search"
