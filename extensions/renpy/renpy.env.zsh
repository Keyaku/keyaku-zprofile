# Ren'Py honours no XDG var (upstream renpy#1377); RENPY_PATH_TO_SAVES relocates
# the whole save tree (per-game saves + tokens/). Games are standalone binaries
# with no command to probe, so we gate on Ren'Py data existing in either
# location — keeping the var off systems that never run Ren'Py. Cost: a
# brand-new install with no data yet creates ~/.renpy on first run; the next
# login migrates it and the var sticks thereafter.
[[ -d "$HOME"/.renpy || -d "$XDG_DATA_HOME"/renpy ]] || return
export RENPY_PATH_TO_SAVES="$XDG_DATA_HOME"/renpy

[[ -d "$HOME"/.renpy ]] && xdg-migrate "$HOME"/.renpy "$RENPY_PATH_TO_SAVES"
