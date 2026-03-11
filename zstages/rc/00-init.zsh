# Initialize submodules if ohmyzsh is not present or empty
[[ "${ZPROFILE_MODULES}" ]] || ZPROFILE_MODULES=($(git -C "$ZDOTDIR" config --file .gitmodules --get-regexp path | awk '{ print $2 }'))
if [[ "$(echo "$ZDOTDIR"/$^ZPROFILE_MODULES/(N^F))" ]]; then
	# Initialize submodules
	zupdate --submodules
fi
