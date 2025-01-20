#######################################
### Homebrew
#######################################

### Loading shell environment
if [[ -d /home/linuxbrew/.linuxbrew && -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
	if ! haspath /home/linuxbrew/.linuxbrew/bin || ! haspath /home/linuxbrew/.linuxbrew/sbin; then
		eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

		# export PKG_CONFIG_PATH="$(pkg-config --variable pc_path pkg-config):$(/usr/bin/pkg-config --variable pc_path pkg-config)"
	fi

	export HOMEBREW_NO_ANALYTICS=1
	export HOMEBREW_NO_ENV_HINTS=1
fi
