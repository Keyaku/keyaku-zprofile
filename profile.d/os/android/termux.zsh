whatami Android || return

alias pkg-all='pkg update && pkg upgrade -y'

### Package Manager APT related aliases
alias apt-update='apt update'
alias apt-upgrade='apt upgrade -y --auto-remove'
alias apt-install='apt install -y --auto-remove'
alias apt-remove='apt remove -y --auto-remove'
alias apt-purge='apt-remove --purge'
alias apt-autoremove='apt autoremove --purge -y'
alias apt-all='apt-update && apt-upgrade'
alias apt-clean='apt-get clean'
alias apt-markauto='apt-mark auto'
alias apt-search='apt-cache search'

### Android development
command-has termux-adb && alias termux-adb="HOME=$ANDROID_HOME termux-adb"
