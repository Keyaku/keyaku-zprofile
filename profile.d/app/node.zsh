#######################################
### NPM (Node.js)
#######################################

# Find npm package to add to PATH
## Check for Flatpak version
! printenv FLATPAK_ENV &>/dev/null && zsource flatpak
if flatpak-has node; then
	NODE_HOME=$(echo ${FLATPAK_ENV[USER_DIR]}/runtime/org.freedesktop.Sdk.Extension.node<->/x86_64/24.08/active/files/bin(OcFY1))
	[[ -d "$NODE_HOME" ]] && addpath "$NODE_HOME"
	unset NODE_HOME
fi
