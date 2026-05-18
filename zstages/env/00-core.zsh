#######################################
### Core environment variables
#######################################

export SHORT_HOST=${SHORT_HOST:-${(%):-%m}}

# Some remote-shell hosts leak JSON nulls as the literal string "null" into
# LD_* vars, which can trip dynamic linkers on every exec. Scrub before
# anything downstream invokes an external binary.
[[ $LD_LIBRARY_PATH == null ]] && unset LD_LIBRARY_PATH
[[ $LD_PRELOAD == null ]] && unset LD_PRELOAD
