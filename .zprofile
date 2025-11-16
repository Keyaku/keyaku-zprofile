#####################################################################
#                            .zprofile
#
# File loaded 2nd && if [[ -o login ]]
#
# Used for executing user's commands at start,
# will be read when starting as a *login shell*.
# Typically used to autostart graphical sessions
# and to set session-wide environment variables.
#####################################################################

### Source path/session functions
[[ -d "${ZDOTDIR}/lib/login" ]] && for zsh_file in "${ZDOTDIR}/lib/login"/*.zsh(N); do
	source "$zsh_file"
done

### Source profile stage
[[ -d "${ZDOTDIR}/profile" ]] && for zsh_file in "${ZDOTDIR}/profile"/*.zsh(N.); do
	source "$zsh_file"
done
unset zsh_file
