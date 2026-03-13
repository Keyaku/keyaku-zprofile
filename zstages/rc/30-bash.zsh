# Bash modules & autocompletion (for programs which contain only bash completions)
if [[ -d "$XDG_DATA_HOME"/bash-completion/completions ]]; then
	local f_bashcomp
	autoload bashcompinit && bashcompinit &&
	for f_bashcomp in "$XDG_DATA_HOME"/bash-completion/completions/*(-N.); do
		source "$f_bashcomp"
	done
fi
