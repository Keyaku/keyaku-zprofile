##############################################################################
# Personal settings for this ZDOTDIR
#
# Copy to $ZDOTDIR/settings.local.zsh (gitignored). It's sourced by .zshenv
# right after lib/core, before any stage, so it affects every kind of shell.
# Keep it to settings: no output, no slow commands.
##############################################################################

# Extensions (directories under $ZDOTDIR/extensions). All load by default.
# Run `zext` at the prompt to list them and their state.
# zext --off docker vscode
# Or load only a chosen few (a name always wins over '*'):
# zext --off '*' --on git ssh ssh-agent gpg pass

