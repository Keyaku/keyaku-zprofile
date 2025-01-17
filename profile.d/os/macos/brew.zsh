if whatami macOS; then

### Homebrew settings
if [[ "${HOMEBREW_PREFIX}" ]]; then

	### SSH
	# export SSH_SK_PROVIDER="$HOMEBREW_CELLAR/openssh/9.0p1/libexec/ssh-sk-helper"
	export SSH_SK_HELPER="$HOMEBREW_CELLAR/openssh/9.0p1/libexec/ssh-sk-helper"

fi

fi
