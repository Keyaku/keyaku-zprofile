#######################################
### Podman
#######################################

if command_has podman; then

### Presume rootless mode
export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"

fi
