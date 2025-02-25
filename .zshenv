#####################################################################
#                            .zshenv
#
# File loaded 1st.
#
# Used for setting user's environment variables;
# it should not contain commands that produce output
# or assume the shell is attached to a TTY.
# When this file exists it will _always_ be read.
#####################################################################

#######################################
### XDG variables
#######################################

# The ~$USER serves as workaround when overriding
# $HOME variable in Flatpaks


### User Directories
export XDG_CACHE_HOME=~$USER/.local/cache
export XDG_CONFIG_HOME=~$USER/.local/config
export XDG_DATA_HOME=~$USER/.local/share
export XDG_STATE_HOME=~$USER/.local/state

### System directories
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-${XDG_DATA_HOME}:/usr/local/share:/usr/share}"
export XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:-${XDG_CONFIG_HOME}:/etc/xdg}"


#######################################
# Environment control
#######################################

### ZSH profile
export ZDOTDIR="${XDG_CONFIG_HOME}/zsh"
export ZSH_CACHE_HOME="${XDG_CACHE_HOME}/zsh"
[[ ! -d "${ZSH_CACHE_HOME}" ]] && mkdir -p "${ZSH_CACHE_HOME}"
export ZSH_COMPDUMP="${ZSH_CACHE_HOME}/zcompdump"
export HISTFILE="${ZSH_CACHE_HOME}/zsh_history"
export HISTCONTROL=ignoredups:erasedups

# Function that checks if current file is being sourced by one of the main zsh profiles
function is_sourced_by {
	setopt extendedglob

	local -ra zprofiles=(.zshenv .zprofile .zshrc .zlogin .zlogout)
	local zpatterns
	local -i argc=$#

	# Specifiy zprofiles if arguments were given
	if (( $argc )); then
		while (( $# )); do
			if [[ -f "$(echo "$ZDOTDIR"/{,.}"${1:t}"(-.N))" ]]; then
				zpatterns="${zpatterns:+$zpatterns|}${1:t}"
			fi
			shift
		done

		if [[ -z "$zpatterns" ]]; then
			# No valid zprofile given
			return 1
		fi
	# Otherwise, check for all zprofiles
	else
		zpatterns="${(j:|:)zprofiles}"
	fi

	[[ "${funcstack[-1]:t}" =~ "^\.?("${zpatterns}")$" ]]
	local retval=$?

	# If no argument given, print the zprofile
	if (( ! $retval && ! $argc )); then
		echo "${funcstack[-1]:t}"
	fi

	return $retval
}


##############################################################################
### Custom packages locations
###
### Any variable here should be set once at boot.
### If a new one is added, a reboot is in order.
###
### Variables that point to config files should be set here.
##############################################################################

### AM/AppMan
if command -v appman &>/dev/null; then
	export SANDBOXDIR=~$USER/.local/app/appman/sandboxes
fi

### Android debugging
if command -v adb &>/dev/null || [[ -d "${XDG_DATA_HOME}/android" ]]; then
	export ANDROID_HOME="${XDG_DATA_HOME}/android"
	[[ -d "$ANDROID_HOME" ]] || mkdir -p "$ANDROID_HOME"
	export ANDROID_USER_HOME="${ANDROID_HOME}/.android"

	# Prevent adb from using user's home directory
	alias adb="HOME=$ANDROID_HOME adb"
fi


### Bundle (Ruby gems)
if command -v bundle &>/dev/null; then
	export BUNDLE_USER_CACHE="${XDG_CACHE_HOME}"/bundle
	export BUNDLE_USER_CONFIG="${XDG_CONFIG_HOME}"/bundle
	export BUNDLE_USER_PLUGIN="${XDG_DATA_HOME}"/bundle
fi

### Cargo
if command -v cargo &>/dev/null; then
	export CARGO_HOME="$XDG_DATA_HOME"/cargo
fi

### Editors
export EDITOR='vim'
export MYVIMRC="${XDG_CONFIG_HOME}/vim/vimrc"

### Less (is more)
export LESSHISTFILE="${XDG_CACHE_HOME}/less/history"
export LESS=' -R '

### Git
export GIT_HOME=~$USER/.local/git
[[ ! -d "$GIT_HOME" ]] && mkdir -p "$GIT_HOME"

### Golang
if command -v go &>/dev/null; then
	export GOPATH="${XDG_DATA_HOME}/go"
fi

### GNUPG & security tools
export GNUPGHOME="${XDG_DATA_HOME}/gnupg"
export PASSWORD_STORE_DIR="${XDG_DATA_HOME}/password-store"
if command -v gpg-agent &>/dev/null && ! killall -0 gpg-agent &>/dev/null; then
	gpg-agent --pinentry-program /usr/bin/pinentry-qt --daemon
fi

### GTK
export GTK2_RC_FILES="${XDG_CONFIG_HOME}/gtkrc-2.0"
export GTK_USE_PORTAL=1


### NPM (Node.js)
if command -v npm &>/dev/null; then
	[[ ! -d "${XDG_CONFIG_HOME}"/npm ]] && mkdir -p "${XDG_CONFIG_HOME}"/npm
	[[ ! -d "${XDG_CACHE_HOME}"/npm ]]  && mkdir -p "${XDG_CACHE_HOME}"/npm
	export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME}"/npm/.npmrc
fi

### Perl
export PERL_LOCAL_LIB_ROOT="${XDG_DATA_HOME}/perl"
export PERL_CPANM_HOME="${PERL_LOCAL_LIB_ROOT}/cpan"

export PERL5LIB="${PERL_CPANM_HOME}:${PERL_LOCAL_LIB_ROOT}/lib/perl5"

export PERL_MB_OPT="--install_base '${PERL_LOCAL_LIB_ROOT}'"
export PERL_MM_OPT="  INSTALL_BASE='${PERL_LOCAL_LIB_ROOT}'"

if command -v cpan &>/dev/null; then
	alias cpan='cpan -j ${PERL_CPANM_HOME}/CPAN/MyConfig.pm'
fi


### SSH
export SSH_HOME=${XDG_CONFIG_HOME}/ssh


### SSL
[[ -f /.flatpak-info ]] && SSL_DIR="/etc/pki/tls" || SSL_DIR="/etc/ssl"
export SSL_DIR
export SSL_CERT_DIR="$SSL_DIR/certs"


### Tk/Tcl, tkinter
export TCL_LIBRARY=/usr/lib/tcl8.6
export TK_LIBRARY=/usr/lib/tk8.6


### wget/curl
if command -v wget &>/dev/null; then
	export WGETRC="${XDG_CONFIG_HOME}/wgetrc"
	[[ ! -d "${XDG_DATA_HOME}"/wget ]] && mkdir -p "${XDG_DATA_HOME}"/wget
	if [[ ! -f $XDG_CONFIG_HOME/wgetrc ]] || ! \grep -Eqw "hsts-file=${XDG_DATA_HOME}/wget/hsts" $XDG_CONFIG_HOME/wgetrc; then
		echo "hsts-file=${XDG_DATA_HOME}/wget/hsts" >> $XDG_CONFIG_HOME/wgetrc
	fi
fi

### X11
# export XAUTHORITY="${XDG_CACHE_HOME}/X11/Xauthority"
export XINITRC="${XDG_CONFIG_HOME}/X11/xinitrc"
