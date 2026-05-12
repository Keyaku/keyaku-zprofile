#!/usr/bin/env bash
# Restrict Portainer's exposed port to LAN-only access via nftables.
# Port is read dynamically from the compose file — no hardcoding needed.
# Usage: portainer-restrict [LAN_SUBNET]
#   LAN_SUBNET can also be set as an env var; defaults to auto-detected.

set -euo pipefail

COMPOSE_FILE="/usr/local/docker/stacks/portainer/compose.yaml"
NFT_TABLE="portainer_guard"

_detect_lan() {
    local iface
    iface=$(ip route show default | awk '{print $5; exit}')
    ip route show dev "$iface" scope link | awk 'NR==1{print $1}'
}

LAN_SUBNET="${1:-${LAN_SUBNET:-$(_detect_lan)}}"

# Parse the first non-commented host port under the ports: key
host_port=$(awk '
    /^[[:space:]]*ports:/     { in_ports=1; next }
    in_ports && /^[[:space:]]*[a-zA-Z]/ { in_ports=0 }
    in_ports && /^[[:space:]]*#/        { next }
    in_ports && match($0, /[0-9]+:[0-9]+/) {
        split(substr($0, RSTART, RLENGTH), a, ":")
        print a[1]; exit
    }
' "$COMPOSE_FILE")

[[ -z "$host_port" ]] && {
    echo "Error: could not parse a host port from $COMPOSE_FILE" >&2
    exit 1
}

echo "Portainer port : $host_port"
echo "LAN subnet     : $LAN_SUBNET"

# Idempotent: drop the dedicated table entirely and recreate it
nft delete table inet "$NFT_TABLE" 2>/dev/null || true

nft -f - <<NFTEOF
table inet $NFT_TABLE {
    chain input {
        type filter hook input priority filter
        policy accept
        tcp dport $host_port ip saddr != { 127.0.0.0/8, $LAN_SUBNET } drop
    }
}
NFTEOF

echo "Applied: port $host_port restricted to $LAN_SUBNET + loopback"
