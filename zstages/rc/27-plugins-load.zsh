##############################################################################
# Plugin loader (with or without Oh-My-Zsh)
##############################################################################
# Sources the plugin files found by 24-fpath.zsh, after compinit. A plugin's
# aliases are dropped when `zstyle ':omz:plugins:<name>' aliases 0` is set.

if (( ${ZSH_PROFILE_BENCHMARK} )); then
	zmodload zsh/datetime
	local -F _t2 _t3 _tsources _tploader0=$EPOCHREALTIME _tploader1
fi

local -A aliases_pre
local plugin plugin_file
local -i disable_aliases

for plugin_file in ${ZPROFILE_PLUGIN_FILES}; do
	plugin="${plugin_file:h:t}"

	disable_aliases=0
	zstyle -T ":omz:plugins:$plugin" aliases || disable_aliases=1

	(( disable_aliases )) && aliases_pre=("${(@kv)aliases}")

	(( ${ZSH_PROFILE_BENCHMARK} )) && _t2=$EPOCHREALTIME
	_zsh_source_file "$plugin_file"
	(( ${ZSH_PROFILE_BENCHMARK} )) && _t3=$EPOCHREALTIME && _tsources=$((_tsources + (_t3-_t2)))

	(( disable_aliases )) && aliases=("${(@kv)aliases_pre}")
done
unset plugin ZPROFILE_PLUGIN_FILES

if (( ${ZSH_PROFILE_BENCHMARK} )); then
	_tploader1=$EPOCHREALTIME
	print "plugin loader: $((_tploader1-_tploader0 - _tsources))s"
fi

# Remove fpath duplicates and empty directories (OMZ adds some); `-` follows
# symlinks, since root's code dirs are links into this repo.
# Comment this line in case fpath is bloated.
fpath=(${(u)^fpath}(-FN))
