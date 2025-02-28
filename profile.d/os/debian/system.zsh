whatami Debian Ubuntu || return

### APT
command-has apt apt-get || return

### APT-related aliases
alias apt-update='sudo apt update'
alias apt-upgrade='sudo apt upgrade -y --auto-remove'
alias apt-install='sudo apt install -y --auto-remove'
alias apt-remove='sudo apt remove -y --auto-remove'
alias apt-purge='apt-remove --purge'
alias apt-autoremove='sudo apt autoremove --purge -y'
alias apt-all='apt-update && apt-upgrade'
alias apt-clean='sudo apt-get clean'
alias apt-markauto='sudo apt-mark auto'
alias apt-search='apt-cache search'
