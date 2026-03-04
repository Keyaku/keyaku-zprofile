export PULSE_COOKIE="$XDG_CONFIG_HOME/pulse/cookie"

if [[ -f "$HOME/.pulse-cookie" && ! -L "$HOME/.pulse-cookie" ]]; then
	mkdir -p "$XDG_CONFIG_HOME/pulse/"
	xdg-migrate "$HOME/.pulse-cookie" "$PULSE_COOKIE"
elif [[ -L "$HOME/.pulse-cookie" && -w /etc/pulse/client.conf ]]; then
	sed -Ei 's@^([#;]\s*)?cookie-file.*@cookie-file = $XDG_CONFIG_HOME/pulse/cookie@' /etc/pulse/client.conf
	rm "$HOME/.pulse-cookie"
fi
