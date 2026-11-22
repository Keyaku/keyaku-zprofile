# ============================================================================
# Drain deferred tasks queued against `compinit`
# ============================================================================
#
# `compinit` ran in 25-omz-load.zsh (OMZ) or 26-compinit.zsh (without OMZ), so
# `compdef` now exists. Flush anything extensions queued via `zdefer compinit …`
# at source time (they were sourced at 10-setup.zsh, before compinit). Kept as a
# separate, numbered stage so the flush point stays explicit.
(( $+functions[zdefer_flush] )) && zdefer_flush compinit
