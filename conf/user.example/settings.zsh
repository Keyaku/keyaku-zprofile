##############################################################################
# Personal settings for this ZDOTDIR
#
# Copy to $ZDOTDIR/user/settings.zsh. It's sourced by .zshenv right after
# lib/core, before any stage, so it affects every kind of shell. Keep it to
# settings: no output, no slow commands.
##############################################################################

# Extensions (directories under $ZDOTDIR/extensions). All load by default.
# Run `zext` at the prompt to list them and their state.
# zext --off docker vscode
# Or load only a chosen few (a name always wins over '*'):
# zext --off '*' --on git ssh ssh-agent gpg pass

# Vendored submodules: ohmyzsh, powerlevel10k, zsh-syntax-highlighting.
# A disabled submodule is neither fetched by `zupdate --submodules` nor loaded.
# - powerlevel10k or zsh-syntax-highlighting off: a distro-installed copy is used
#   if present; otherwise the prompt falls back to robbyrussell (or the theme
#   set below) and there's no highlighting.
# - To skip powerlevel10k even with a distro copy installed, pick another theme:
# ZSH_THEME=robbyrussell
# - ohmyzsh off: no OMZ, which today also means no compinit and no plugins.
# zsubmod --off powerlevel10k
