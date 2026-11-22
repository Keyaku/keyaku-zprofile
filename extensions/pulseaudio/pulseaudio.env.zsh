(( ${+commands[pulseaudio]} || ${+commands[pactl]} )) || [[ -e "$HOME/.pulse-cookie" ]] || return

export PULSE_COOKIE="$XDG_CONFIG_HOME/pulse/cookie"

# Clients without this variable (e.g. started outside the session) learn the
# path from $XDG_CONFIG_HOME/pulse/client.conf, which first_init's setup_pulse
# writes.
if [[ -f "$HOME/.pulse-cookie" && ! -L "$HOME/.pulse-cookie" ]]; then
	xdg-migrate -e PULSE_COOKIE "$HOME/.pulse-cookie" "$PULSE_COOKIE"
fi
