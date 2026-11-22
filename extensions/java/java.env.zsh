(( ${+commands[java]} || ${+commands[javac]} )) || return

export GRADLE_USER_HOME="$XDG_DATA_HOME"/gradle
[[ -d "$HOME"/.gradle ]] && xdg-migrate -e GRADLE_USER_HOME "$HOME"/.gradle "$GRADLE_USER_HOME"
