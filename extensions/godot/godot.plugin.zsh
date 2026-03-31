# Prioritize flatpak version
if (( ${#commands[org.godotengine.Godot]} )); then
	alias godot='org.godotengine.Godot'
fi

if (( ${#commands[godot]} )); then
	: # insert stuff here
fi
