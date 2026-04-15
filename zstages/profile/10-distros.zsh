##############################################################################
### Setting Distro-specific profiles
###
### Anything PATH, fpath or related should be added or modified here.
##############################################################################

if whatami Debian; then
	# Debian uses ridiculous tricks to set PATH, PS1 and BASH, and loading /etc/profile.d.
	# We can't have that, so I'll just use the tools from this environment to set things up.
	addpath /usr/local/sbin /usr/local/bin /usr/sbin
	_zsh_source_dir /etc/profile.d profile.d '*.sh'

	# Snippet taken from Arch's /etc/profile:
	# Source global bash config, when interactive but not posix or sh mode
	if test "$BASH" && \
		test "$PS1" && \
		test -z "$POSIXLY_CORRECT" && \
		test "${0#-}" != sh && \
		test -r /etc/bash.bashrc
	then
		. /etc/bash.bashrc
	fi

	# Replicate Arch's /etc/profile.d/flatpak-bindir.sh, missing in Debian
	if [[ ! -f /etc/profile.d/flatpak-bindir.sh ]]; then
		addpath "$XDG_DATA_HOME/flatpak/exports/bin" /var/lib/flatpak/exports/bin
	fi

	# Avoid Debian's compinit at /etc/zsh/zshrc
	skip_global_compinit=1
fi
