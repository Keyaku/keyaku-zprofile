### Adding to PATH

# Add a local bin directory to path
[[ -d "$HOME/.local/bin" ]] || mkdir -p "$HOME/.local/bin"
haspath "$HOME/.local/bin" || addpath -p "$HOME/.local/bin"
