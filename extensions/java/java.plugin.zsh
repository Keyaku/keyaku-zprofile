(( ${(v)#commands[(I)java|javac]} )) || return

export GRADLE_USER_HOME="$XDG_DATA_HOME"/gradle

# TODO: create migrating function for these cases
if [[ -d $HOME/.gradle ]]; then
	echo "Migrating $HOME/.gradle to $GRADLE_USER_HOME..."
	if [[ -d "$GRADLE_USER_HOME" ]]; then
		rsync -Prazq $HOME/.gradle/ "$GRADLE_USER_HOME" && rm -r $HOME/.gradle
	else
		mv $HOME/.gradle "$GRADLE_USER_HOME"
	fi
fi
