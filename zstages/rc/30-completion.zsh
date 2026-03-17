# Bash modules & autocompletion (for programs which contain only bash completions)
if [[ -d "$XDG_DATA_HOME"/bash-completion/completions ]]; then
	# Presume bashcompinit was already executed if it's loaded
	(( ${+functions[bashcompinit]} )) || { autoload -U +X bashcompinit && bashcompinit; }

	local f_bashcomp
	for f_bashcomp in "$XDG_DATA_HOME"/bash-completion/completions/*(-N.); do
		source "$f_bashcomp"
	done
fi
