##############################################################################
### Custom packages locations
###
### Any variable here should be set once at boot.
### If a new one is added, a reboot is in order.
###
### Variables that point to config files should be set here.
##############################################################################

### AM/AppMan
if (( ${+commands[appman]} )); then
	export SANDBOXDIR=$HOME/.local/app/appman/sandboxes
fi

### Bundle (Ruby gems)
if (( ${+commands[bundle]} )); then
	export BUNDLE_USER_CACHE="${XDG_CACHE_HOME}"/bundle
	export BUNDLE_USER_CONFIG="${XDG_CONFIG_HOME}"/bundle
	export BUNDLE_USER_PLUGIN="${XDG_DATA_HOME}"/bundle
fi

### Cargo
if (( ${+commands[cargo]} )); then
	export CARGO_HOME="$XDG_DATA_HOME"/cargo
fi

### Less (is more)
if (( ${+commands[less]} )); then
	export LESSHISTFILE="${XDG_CACHE_HOME}/less/history"
	export LESS=' -R '
fi

### Golang
if (( ${+commands[go]} )); then
	export GOPATH="${XDG_DATA_HOME}/go"
fi

### GNUPG & security tools
source "${ZDOTDIR}"/extensions/gpg/gpg.plugin.zsh
source "${ZDOTDIR}"/extensions/gpg/gpg-agent.plugin.zsh
export PASSWORD_STORE_DIR="${XDG_DATA_HOME}/password-store"

### GTK
export GTK2_RC_FILES="${XDG_CONFIG_HOME}/gtkrc-2.0"
export GTK_USE_PORTAL=1

### Mesa
export MESA_SHADER_CACHE_DIR="${XDG_CACHE_HOME}/mesa_shader_cache"

### Perl
if (( ${+commands[perl]} )); then
	export PERL_LOCAL_LIB_ROOT="${XDG_DATA_HOME}/perl"
	export PERL_CPANM_HOME="${PERL_LOCAL_LIB_ROOT}/cpan"

	export PERL5LIB="${PERL_CPANM_HOME}:${PERL_LOCAL_LIB_ROOT}/lib/perl5"

	export PERL_MB_OPT="--install_base '${PERL_LOCAL_LIB_ROOT}'"
	export PERL_MM_OPT="  INSTALL_BASE='${PERL_LOCAL_LIB_ROOT}'"
fi

if (( ${+commands[cpan]} )); then
	alias cpan='cpan -j ${PERL_CPANM_HOME}/CPAN/MyConfig.pm'
fi


### SSH
if (( ${+commands[ssh]} )); then
	export SSH_HOME=${XDG_CONFIG_HOME}/ssh
fi


### SSL
# Avoid setting root-based paths in Termux
if (( ! ${+TERMUX_VERSION} )); then
	export SSL_DIR="/etc/ssl"
	export SSL_CERT_DIR="$SSL_DIR/certs"
fi


### Tk/Tcl, tkinter
if [[ -d /usr/lib/tcl8.6 && -d /usr/lib/tk8.6 ]]; then
	export TCL_LIBRARY=/usr/lib/tcl8.6
	export TK_LIBRARY=/usr/lib/tk8.6
fi


### wget/curl
if (( ${+commands[wget]} )); then
	export WGETRC="${XDG_CONFIG_HOME}/wgetrc"
	[[ ! -d "${XDG_DATA_HOME}"/wget ]] && mkdir -p "${XDG_DATA_HOME}"/wget
	if [[ ! -f $XDG_CONFIG_HOME/wgetrc ]] || ! \grep -Eqw "hsts-file=${XDG_DATA_HOME}/wget/hsts" $XDG_CONFIG_HOME/wgetrc; then
		echo "hsts-file=${XDG_DATA_HOME}/wget/hsts" >> $XDG_CONFIG_HOME/wgetrc
	fi
fi

### X11
# export XAUTHORITY="${XDG_CACHE_HOME}/X11/Xauthority"
export XINITRC="${XDG_CONFIG_HOME}/X11/xinitrc"
