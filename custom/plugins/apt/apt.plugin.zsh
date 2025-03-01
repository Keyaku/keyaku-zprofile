# Select exclusively Debian or Ubuntu
whatami Debian Ubuntu || return

(( ${(v)+commands[(I)apt|apt-get]} )) || return

SUDO=$(whatami Android || echo sudo)

### APT-related aliases
alias apt-update="$SUDO apt update"
alias apt-upgrade="$SUDO apt upgrade -y --auto-remove"
alias apt-install="$SUDO apt install -y --auto-remove"
alias apt-remove="$SUDO apt remove -y --auto-remove"
alias apt-purge="apt-remove --purge"
alias apt-autoremove="$SUDO apt autoremove --purge -y"
alias apt-all="apt-update && apt-upgrade"
alias apt-clean="$SUDO apt-get clean"
alias apt-markauto="$SUDO apt-mark auto"
alias apt-search="apt-cache search"
