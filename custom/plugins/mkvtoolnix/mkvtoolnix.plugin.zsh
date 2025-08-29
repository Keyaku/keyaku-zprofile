(( ${(v)#commands[(I)mkvtoolinx-gui|org.bunkus.mkvtoolnix-gui]} )) || return

# Flatpak version
if (( ${+commands[org.bunkus.mkvtoolnix-gui]} )); then
	# Alias the mkv- commands from the Flatpak package
	MKVTOOLNIX_CMDS=(mkvextract mkvinfo mkvmerge mkvmerge mkvpropedit mkvtoolnix)

	for _mkvcmd in ${MKVTOOLNIX_CMDS}; do
		alias ${_mkvcmd}="flatpak run --command=${_mkvcmd} org.bunkus.mkvtoolnix-gui"
	done

	unset _mkvcmd MKVTOOLNIX_CMDS
fi
