##############################################################################
### Setting Distro-specific profiles
###
### Anything PATH, fpath or related should be added or modified here.
##############################################################################

if whatami Debian; then
	# Debian discriminately resets PATH in this file, so any paths added prior
	# are discarded.
	emulate sh -c "source /etc/profile"
fi
