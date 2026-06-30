# ============================================================================
# Drain deferred tasks queued against `compinit`
# ============================================================================
#
# `compinit` ran inside 25-omz-load.zsh, so `compdef` now exists. Flush anything
# extensions queued via `zdefer compinit …` at source time (they were sourced at
# 10-setup.zsh, before compinit). Kept as a separate, numbered stage so the flush
# point stays explicit and independent of OMZ-load internals (which early-return
# when OMZ is absent — in that case nothing was ever queued, so this no-ops).
(( $+functions[zdefer_flush] )) && zdefer_flush compinit
