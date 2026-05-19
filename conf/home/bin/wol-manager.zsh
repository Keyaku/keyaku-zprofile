#!/usr/bin/env zsh

emulate -L zsh
setopt pipefail

### CONSTANTS

# Standardized $0 handling
# https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#zero-handling
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

readonly THIS=${0:t}
readonly THIS_NAME=${THIS:r}

# Shared script libs (bootstrap pulls in lib/core + lib/interactive).
source "${ZDOTDIR}/lib/script/bootstrap.zsh"
source "${ZDOTDIR}/lib/script/table.zsh"
source "${ZDOTDIR}/lib/script/config.zsh"
source "${ZDOTDIR}/lib/script/json-store.zsh"

# Hard requirements (gpg is needed even for plaintext stores: sync, cloud bootstrap)
command-has -av jaq gpg || exit 1
# Soft requirements (dig/host); fallbacks exist via getent/ping.
command-has -o dig host getent ping || \
	print_fn -w "No hostname/IP resolver tools found; resolution by hostname or IP may fail."

readonly -a usage=(
	"Usage: ${THIS} [OPTION...] COMMAND [ARGUMENT...]"
	"\t[-h|--help] : Print this help message"
	"\t[-v] / [-q] : Increase / Decrease verbosity"
	""
	"COMMANDS"
	"\tadd TARGET                Add or update a device from MAC, hostname, or IP"
	"\tremove QUERY              Remove a registered device"
	"\tlist [--all]              List devices for the current network (or all)"
	"\tstatus [--all]            Ping registered devices and print online/offline status"
	"\tedit QUERY [OPTION...]    Edit the matched device with flags, or open it in \$EDITOR"
	"\twake QUERY                Wake a device by MAC, hostname, IP, or id"
	"\tget QUERY [OPTION...]     Print a matching device's MAC address or selected fields"
	"\tsync [--pull]             Encrypt local store to cloud (or pull cloud → local)"
	"\tconfig [path]             Print storage config, or path to the config file"
	""
	"GET OPTIONS"
	"\t--all                     Print the full registered device record"
	"\t--mac                     Print MAC address"
	"\t--hostname, --name        Print hostname/name"
	"\t--ip                      Print last IP"
	"\t--network                 Print last-seen network name"
	"\t--network-id, --network-ids  Print all associated network ids (one per line)"
	"\t--id                      Print device id"
	"\t--created, --updated      Print timestamps"
	""
	"EDIT OPTIONS"
	"\t--hostname HOST           Set hostname/name"
	"\t--id ID                   Set device id"
	"\t--ip IP                   Set last IP"
	"\t--mac MAC                 Set MAC address"
	"\t--network NETWORK_ID      Add network id to the device's list; use 'current' for the active network"
)

# --- Storage paths ---
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$THIS_NAME"
readonly CONFIG_FILE_PATH="$CONFIG_DIR/config.json"
readonly DEFAULT_LOCAL_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/$THIS_NAME/macs.json"
if [[ -n "$XDG_DOCUMENTS_DIR" && -d "$XDG_DOCUMENTS_DIR" ]]; then
	readonly DEFAULT_CLOUD_PATH="$XDG_DOCUMENTS_DIR/Workspaces/macs.json.gpg"
else
	readonly DEFAULT_CLOUD_PATH=""
fi

# Set during init
typeset -g MAC_FILE_PATH=""
typeset -g LOCAL_PATH=""
typeset -g CLOUD_PATH=""
typeset -ag GPG_OPTS=()
typeset -ga WOL_CMD=()
typeset -gi verbosity=0

# --- Configuration ---

function _config_default_json {
	jaq -n \
		--arg local "$DEFAULT_LOCAL_PATH" \
		--arg cloud "$DEFAULT_CLOUD_PATH" \
		'{
			store_path: null,
			paths: {
				local: $local,
				cloud: (if $cloud == "" then null else $cloud end)
			}
		}'
}

function _config_coerce {
	jaq \
		--arg local "$DEFAULT_LOCAL_PATH" \
		--arg cloud "$DEFAULT_CLOUD_PATH" \
		'{
			store_path: (.store_path // null),
			paths: {
				local: (.paths.local // $local),
				cloud: (.paths.cloud // (if $cloud == "" then null else $cloud end))
			}
		}'
}

function _config_value { config_value "$CONFIG_FILE_PATH" "$1" }

# Resolve MAC_FILE_PATH and (optionally) bootstrap from cloud.
function _init_paths {
	config_ensure "$CONFIG_FILE_PATH" _config_default_json _config_coerce || return 1

	# Single jaq pass: extract local, cloud, store_path as TSV.
	local configured
	IFS=$'\t' read -r LOCAL_PATH CLOUD_PATH configured < <(
		jaq -r '[.paths.local // "", .paths.cloud // "", .store_path // ""] | @tsv' "$CONFIG_FILE_PATH"
	)

	if [[ -n "$WOL_MANAGER_MAC_FILE_PATH" ]]; then
		MAC_FILE_PATH="$WOL_MANAGER_MAC_FILE_PATH"
		return 0
	fi

	if [[ -n "$configured" ]]; then
		MAC_FILE_PATH="$configured"
		return 0
	fi

	MAC_FILE_PATH="$LOCAL_PATH"

	# Local already populated → done.
	[[ -s "$MAC_FILE_PATH" ]] && return 0

	# Local missing/empty → try cloud bootstrap.
	[[ -n "$CLOUD_PATH" && -f "$CLOUD_PATH" ]] || return 0

	if [[ "${CLOUD_PATH:e}" != "gpg" ]]; then
		print_fn -w "Cloud store '%s' is unencrypted; ignoring for security reasons." "$CLOUD_PATH"
		return 0
	fi

	[[ -d "${MAC_FILE_PATH:h}" ]] || mkdir -p "${MAC_FILE_PATH:h}" || return 1
	local -a gpg_args=("${GPG_OPTS[@]}" --decrypt --output "$MAC_FILE_PATH")
	(( verbosity > 0 )) || gpg_args+=(--quiet)
	if gpg "${gpg_args[@]}" "$CLOUD_PATH" 2>/dev/null; then
		print_fn -i "Bootstrapped local store from cloud: %s" "$CLOUD_PATH"
	else
		print_fn -e "Failed to decrypt cloud store '%s'." "$CLOUD_PATH"
		rm -f "$MAC_FILE_PATH"
		return 1
	fi
}

# --- Generic helpers ---

function _warn_no_network {
	print_fn -w "No active network detected. Current-network filtering is unavailable."
}

# Coercion applied to a valid {version, devices:[...]} store on read:
# drop legacy _uuid, promote singular network_id → network_ids[].
readonly DEVICES_COERCE='
	.devices |= map(
		del(._uuid)
		| (.network_ids //= (
			if (.network_id // "") != "" then [.network_id] else [] end
		  ))
		| del(.network_id)
	)
'

function _json_read {
	# Fast path: file matches the modern {version, devices:[]} schema.
	if jstore_read "$MAC_FILE_PATH" devices "$DEVICES_COERCE" 2>/dev/null; then
		return 0
	fi

	# Legacy / migration path: read raw, attempt to convert {hostname: mac, ...}.
	local raw
	raw="$(jstore_decrypt "$MAC_FILE_PATH")" || return 1

	[[ -n "$raw" ]] || {
		print_fn -e "Device store is empty; refusing to treat it as valid."
		return 1
	}

	if ! jaq -e 'type == "object"' >/dev/null 2>&1 <<< "$raw"; then
		print_fn -e "Device store is not valid JSON."
		return 1
	fi

	# Migrate legacy {hostname: mac, ...} → versioned device list.
	jaq '{
		version: 1,
		devices: (to_entries | map({
			id: (.key | ascii_downcase | gsub("[^a-z0-9._-]+";"-") | gsub("^-+|-+$";"")),
			hostname: .key,
			mac: .value,
			last_ip: null,
			network_ids: [],
			network_name: null,
			created_at: null,
			updated_at: null
		}))
	}' <<< "$raw" 2>/dev/null || jstore_empty devices
}

function _json_write { jstore_write "$MAC_FILE_PATH" devices }

# --- MAC / IP helpers ---

function mac_verify {
	[[ -n "$1" && "$1" =~ '^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$|^([0-9A-Fa-f]{4}\.){2}[0-9A-Fa-f]{4}$' ]]
}

function mac_normalize {
	local mac="${1:l}"
	mac="${mac//-/:}"

	if [[ "$mac" =~ '^([0-9a-f]{4}\.){2}[0-9a-f]{4}$' ]]; then
		mac="${mac//./}"
		print "${mac[1,2]}:${mac[3,4]}:${mac[5,6]}:${mac[7,8]}:${mac[9,10]}:${mac[11,12]}"
	else
		print -- "$mac"
	fi
}

function ip_verify {
	[[ "$1" =~ '^([0-9]{1,3}\.){3}[0-9]{1,3}$' ]]
}

# --- Network discovery ---

function current_network_json {
	local -a f_ssid
	zparseopts -D -F -K -- {s,-ssid}=f_ssid || return 1

	local iface gateway addr cidr ssid network_id network_name route_line gateway_mac subnet

	# `getprop` is Android-only; when present, `route -n` and `/proc/net/route`
	# are both broken (SELinux-restricted), so skip those probes — ifconfig is
	# the only working source.
	local -i is_android=$+commands[getprop]

	if (( ! is_android && $+commands[ip] )); then
		route_line="$(ip route show default 2>/dev/null | head -n 1)"
		if [[ -n "$route_line" ]]; then
			local -a words=(${=route_line})
			local idx
			idx=${words[(i)dev]}
			(( idx <= ${#words} )) && iface="${words[$idx+1]}"
			idx=${words[(i)via]}
			(( idx <= ${#words} )) && gateway="${words[$idx+1]}"
		fi

		[[ -n "$iface" ]] && addr="$(ip -o -4 addr show dev "$iface" 2>/dev/null | awk '{print $4; exit}')"
		[[ -n "$iface" ]] && subnet="$(ip -o -4 route show dev "$iface" 2>/dev/null | awk '$1 ~ /\// && $1 != "default" {print $1; exit}')"
	fi

	if (( ! is_android )) && [[ -z "$iface" ]] && (( $+commands[route] )); then
		route_line="$(route -n 2>/dev/null | awk '$1 == "0.0.0.0" {print; exit}')"
		if [[ -n "$route_line" ]]; then
			local -a words=(${=route_line})
			gateway="$words[2]"
			iface="$words[-1]"
		fi
	fi

	# Fallback (Android/Termux primary path): /proc/net/route is SELinux-restricted
	# and `route -n` produces an unparseable layout. Parse ifconfig directly:
	# emit one TAB-joined `name<TAB>addr<TAB>netmask` per IPv4 LAN iface, skipping
	# loopback and point-to-point links (cellular rmnet* is /32).
	if [[ -z "$iface" ]] && (( $+commands[ifconfig] )); then
		local if_name if_addr if_mask
		while IFS=$'\t' read -r if_name if_addr if_mask; do
			[[ -n "$if_name" && -n "$if_addr" && -n "$if_mask" ]] || continue
			iface="$if_name"
			addr="$if_addr"
			# Derive subnet (network/CIDR) from addr + netmask.
			local -a _a _m
			_a=(${(s:.:)if_addr})
			_m=(${(s:.:)if_mask})
			local -i _bits=0 _i _oct
			for _i in 1 2 3 4; do
				_oct=$_m[$_i]
				while (( _oct )); do (( _bits += _oct & 1, _oct >>= 1 )); done
			done
			subnet="$(( _a[1] & _m[1] )).$(( _a[2] & _m[2] )).$(( _a[3] & _m[3] )).$(( _a[4] & _m[4] ))/${_bits}"
			break
		done < <(ifconfig 2>/dev/null | awk '
			BEGIN { RS = ""; FS = "\n" }
			{
				name = ""; ipaddr = ""; mask = ""
				split($1, h, /[: ]/); name = h[1]
				if (name == "" || name == "lo") next
				for (i = 1; i <= NF; i++) {
					line = $i
					if (match(line, /inet (addr:)?[0-9.]+/)) {
						s = substr(line, RSTART, RLENGTH)
						sub(/^inet (addr:)?/, "", s)
						ipaddr = s
					}
					if (match(line, /(netmask|Mask:)[ ]*[0-9.]+/)) {
						s = substr(line, RSTART, RLENGTH)
						sub(/^(netmask|Mask:)[ ]*/, "", s)
						mask = s
					}
				}
				if (ipaddr == "" || mask == "" || mask == "255.255.255.255") next
				printf "%s\t%s\t%s\n", name, ipaddr, mask
			}')
	fi

	if [[ -z "$gateway" && -n "$iface" ]] && (( is_android )); then
		gateway="$(getprop "dhcp.${iface}.gateway" 2>/dev/null)"
		[[ -z "$gateway" ]] && gateway="$(getprop "net.${iface}.gw" 2>/dev/null)"
	fi

	# SSID lookup is expensive on Termux (~500 ms binder cold-start per backend)
	# and only needed for the human-readable network_name shown when a device is
	# added. Filtering uses network_id (gateway MAC / subnet), so skip by default.
	if (( ${#f_ssid} )) && [[ -n "$iface" ]]; then
		if command-has nmcli; then
			ssid="$(nmcli -t -f GENERAL.CONNECTION device show "$iface" 2>/dev/null | sed 's/^GENERAL.CONNECTION://')"
			[[ "$ssid" == "--" ]] && unset ssid
		fi
		# Termux/Android: nmcli is absent. Try Termux:API (needs Location perm),
		# then fall back to Shizuku `rish` for `cmd wifi status`.
		if [[ -z "$ssid" ]] && command-has termux-wifi-connectioninfo; then
			ssid="$(termux-wifi-connectioninfo 2>/dev/null | jaq -r '.ssid // empty' 2>/dev/null)"
			# Strip surrounding quotes Android wraps the SSID in.
			ssid="${ssid#\"}"; ssid="${ssid%\"}"
			[[ "$ssid" == "<unknown ssid>" || "$ssid" == "null" ]] && unset ssid
		fi
		if [[ -z "$ssid" ]] && command-has rish; then
			ssid="$(rish -c 'cmd -w wifi status' 2>/dev/null \
				| awk -F'"' '/SSID:/ {print $2; exit}')"
			[[ "$ssid" == "<unknown ssid>" ]] && unset ssid
		fi
	fi

	# System-independent ID: gateway MAC (most stable), else subnet, else legacy fallback.
	[[ -n "$gateway" ]] && gateway_mac="$(_mac_from_ip "$gateway" 2>/dev/null)"

	cidr="${addr:-unknown}"
	network_name="${ssid:-${iface:-unknown}}"

	if [[ -n "$gateway_mac" ]]; then
		network_id="mac:$gateway_mac"
	elif [[ -n "$subnet" ]]; then
		network_id="net:$subnet"
	elif [[ -n "$iface" || -n "$gateway" || -n "$addr" ]]; then
		network_id="${ssid:-$iface}:${cidr}:${gateway:-no-gateway}"
	fi

	if [[ -n "$network_id" ]]; then
		jaq -n \
			--arg id "$network_id" \
			--arg name "$network_name" \
			--arg iface "$iface" \
			--arg gateway "$gateway" \
			--arg gateway_mac "$gateway_mac" \
			--arg subnet "$subnet" \
			--arg cidr "$cidr" \
			'{connected:true,id:$id,name:$name,iface:$iface,gateway:$gateway,gateway_mac:$gateway_mac,subnet:$subnet,cidr:$cidr}'
	else
		jaq -n '{connected:false,id:null,name:null,iface:null,gateway:null,gateway_mac:null,subnet:null,cidr:null}'
	fi
}

function _resolve_ip {
	local target="$1" ip
	ip_verify "$target" && { print -- "$target"; return 0 }

	if command-has getent; then
		ip="$(getent ahostsv4 "$target" 2>/dev/null | awk '$1 ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}$/ {print $1; exit}')"
		[[ -z "$ip" ]] && ip="$(getent hosts "$target" 2>/dev/null | awk '$1 ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}$/ {print $1; exit}')"
		[[ -n "$ip" ]] && { print -- "$ip"; return 0 }
	fi

	if command-has dig; then
		ip="$(dig +short A "$target" 2>/dev/null | awk '/^([0-9]{1,3}\.){3}[0-9]{1,3}$/ {print; exit}')"
		[[ -n "$ip" ]] && { print -- "$ip"; return 0 }
	fi

	if command-has host; then
		ip="$(host "$target" 2>/dev/null | awk '/has address/ {print $NF; exit}')"
		[[ -n "$ip" ]] && { print -- "$ip"; return 0 }
	fi

	if command-has ping; then
		ip="$(ping -c 1 -W 1 "$target" 2>/dev/null | awk -F'[()]' 'NR == 1 && NF >= 2 {print $2; exit}')"
		[[ -n "$ip" ]] && { print -- "$ip"; return 0 }
	fi
}

function _resolve_hostname {
	local ip="$1" host
	[[ -n "$ip" ]] || return 0

	if command-has getent; then
		host="$(getent hosts "$ip" 2>/dev/null | awk '{print $2; exit}')"
		[[ -n "$host" ]] && { print -- "${host%.}"; return 0 }
	fi

	command-has avahi-resolve-address && \
		avahi-resolve-address "$ip" 2>/dev/null | awk '{print $2; exit}' | sed 's/[.]$//'
}

function _local_search_domains {
	{
		[[ -r /etc/resolv.conf ]] && awk '
			$1 == "search" { for (i = 2; i <= NF; i++) print $i }
			$1 == "domain" { print $2 }
		' /etc/resolv.conf 2>/dev/null

		command-has nmcli && nmcli -t -f IP4.DOMAIN device show 2>/dev/null \
			| sed 's/^IP4.DOMAIN\[[0-9]*\]://'

		command-has hostname && hostname -d 2>/dev/null

		print lan
	} | awk 'NF && !seen[$0]++ { gsub(/^[~.]+|[.]$/, "", $0); if ($0 != "") print $0 }'
}

function _qualify_hostname {
	local hostname="${1%.}" ip="$2"
	local domain candidate candidate_ip

	[[ -n "$hostname" ]] || return 0
	[[ "$hostname" == *.* ]] && { print -- "$hostname"; return 0 }

	for domain in "${(@f)$(_local_search_domains)}"; do
		candidate="${hostname}.${domain}"
		candidate_ip="$(_resolve_ip "$candidate")"
		if [[ -n "$candidate_ip" && ( -z "$ip" || "$candidate_ip" == "$ip" ) ]]; then
			print -- "$candidate"
			return 0
		fi
	done

	print -- "$hostname"
}

function _prime_neighbor_cache {
	[[ -n "$1" ]] || return 0
	command-has ping && ping -c 1 -W 1 "$1" >/dev/null 2>&1
	return 0
}

function _mac_from_ip {
	local ip="$1" mac line
	[[ -n "$ip" ]] || return 1
	_prime_neighbor_cache "$ip"

	if command-has ip; then
		line="$(ip neigh show "$ip" 2>/dev/null | head -n 1)"
		local -a words=(${=line})
		local idx=${words[(i)lladdr]}
		(( idx <= ${#words} )) && mac="$words[$idx+1]"
	fi

	[[ -z "$mac" ]] && command-has arp && \
		mac="$(arp -n "$ip" 2>/dev/null | awk 'NR > 1 {print $3; exit}')"

	# Fallback (Termux/minimal envs): read kernel ARP cache directly.
	[[ -z "$mac" && -r /proc/net/arp ]] && \
		mac="$(awk -v ip="$ip" 'NR > 1 && $1 == ip {print $4; exit}' /proc/net/arp)"

	# Fallback (Termux/Android): /proc/net/arp is SELinux-restricted for non-root
	# apps; rish (Shizuku) runs as shell uid and can read it. The Shizuku/app_process
	# bridge is occasionally racy and returns an empty result, so retry briefly.
	if [[ -z "$mac" ]] && command-has rish; then
		print_fn -i "Falling back to rish (Shizuku) to read /proc/net/arp for $ip"
		local -i _attempt
		local _arp_tmp="${TMPDIR:-${PREFIX:-/var}/tmp}/wol-mgr-arp.$$"
		for _attempt in 1 2 3; do
			rish -c 'cat /proc/net/arp' </dev/null >"$_arp_tmp" 2>/dev/null
			[[ -s "$_arp_tmp" ]] && break
			sleep 0.2
		done
		mac="$(awk -v ip="$ip" 'NR > 1 && $1 == ip {print $4; exit}' "$_arp_tmp" 2>/dev/null)"
		rm -f "$_arp_tmp"
	fi

	mac_verify "$mac" && { mac_normalize "$mac"; return 0 }
	return 1
}

function _discover_device_json {
	local target="$1"
	local mac ip hostname network

	network="$(current_network_json --ssid 2>/dev/null)"
	jaq -e 'type == "object" and has("connected")' >/dev/null 2>&1 <<< "$network" \
		|| network="$(jaq -n '{connected:false,id:null,name:null,iface:null,gateway:null,gateway_mac:null,subnet:null,cidr:null}')"

	if mac_verify "$target"; then
		mac="$(mac_normalize "$target")"
	elif ip_verify "$target"; then
		ip="$target"
		mac="$(_mac_from_ip "$ip")"
		hostname="$(_resolve_hostname "$ip")"
	else
		hostname="$target"
		ip="$(_resolve_ip "$target")"
		[[ -n "$ip" ]] && mac="$(_mac_from_ip "$ip")"
	fi

	mac_verify "$mac" || {
		print_fn -e "Could not determine a MAC address for '$target'. Try adding from the device's IP while it is online, or pass the MAC address directly."
		return 1
	}

	if [[ -n "$ip" && ( -z "$hostname" || "$hostname" == "$ip" ) ]]; then
		local resolved; resolved="$(_resolve_hostname "$ip")"
		[[ -n "$resolved" ]] && hostname="$resolved"
	fi

	hostname="$(_qualify_hostname "$hostname" "$ip")"

	jaq -n \
		--arg mac "$(mac_normalize "$mac")" \
		--arg hostname "$hostname" \
		--arg ip "$ip" \
		--argjson network "$network" \
		'{
			mac: $mac,
			hostname: (if ($hostname | length) > 0 then $hostname else null end),
			last_ip: (if ($ip | length) > 0 then $ip else null end),
			network_id: (if $network.connected then $network.id else null end),
			network_name: (if $network.connected then $network.name else null end)
		}'
}

# --- Device lookup and printing ---

function _device_filter_jq {
	cat <<'JQ'
def normmac:
	ascii_downcase
	| gsub("-";":")
	| if test("^([0-9a-f]{4}\\.){2}[0-9a-f]{4}$")
	  then gsub("\\.";"") | [.[0:2],.[2:4],.[4:6],.[6:8],.[8:10],.[10:12]] | join(":")
	  else .
	  end;
def shortname: split(".")[0];
def name_matches($value):
	($value // "" | ascii_downcase) as $stored
	| ($query | ascii_downcase) as $wanted
	| $stored == $wanted
	  or (($stored | contains(".") | not) and ($wanted | contains(".")) and $stored == ($wanted | shortname))
	  or (($stored | contains(".")) and ($wanted | contains(".") | not) and ($stored | shortname) == $wanted);

.devices
| map(select(
	(.mac | ascii_downcase) == ($query | normmac)
	or name_matches(.hostname)
	or (.last_ip // "") == $query
	or name_matches(.id)
	or ((.id // "" | ascii_downcase) | startswith($query | ascii_downcase))
))
JQ
}

function _find_device_json {
	local query="$1"
	_json_read | jaq -e --arg query "$query" \
		"$(_device_filter_jq) | if length == 1 then .[0] elif length == 0 then empty else error(\"ambiguous\") end" 2>/dev/null
}

function _print_devices {
	local json="$1"
	local filter="${2:-.devices}"

	{
		print $'HOSTNAME\tMAC\tLAST_IP\tNETWORK\tID'
		jaq -r "$filter | if length == 0 then empty else .[] | [
			(.hostname // \"-\"),
			(.mac // \"-\"),
			(.last_ip // \"-\"),
			(.network_name // \"-\"),
			(.id // \"-\")
		] | @tsv end" <<< "$json"
	} | print_tsv_table
}

# --- Commands ---

function mac_add {
	local target="$1"
	[[ -n "$target" ]] || { print -u2 "Usage: $THIS add <MAC|hostname|IP>"; return 1; }

	local discovered data when
	discovered="$(_discover_device_json "$target")" || return 1
	data="$(_json_read)" || return 1
	when="$(now)"

	jaq \
		--argjson incoming "$discovered" \
		--arg now "$when" \
		'
		def slug:
			ascii_downcase | gsub("[^a-z0-9._-]+";"-") | gsub("^-+|-+$";"");

		.devices //= []
		| (($incoming.hostname // "") as $h
			| if $h != "" then ($h | split(".")[0]) else ($incoming.last_ip // $incoming.mac) end
			| slug) as $base_id
		| ($incoming.network_id // null) as $cur_id
		| (if $cur_id then [$cur_id] else [] end) as $cur_ids
		| ($incoming | del(.network_id)) as $payload
		| ($incoming.mac | ascii_downcase) as $mac
		| (.devices | map(.mac | ascii_downcase) | index($mac)) as $idx
		| if $idx == null then
			.devices += [($payload + {
				network_ids: $cur_ids,
				id: $base_id,
				created_at: $now,
				updated_at: $now
			})]
		else
			.devices[$idx] |= (
				. as $orig
				| . + $payload
				| .network_ids = ((($orig.network_ids // []) + $cur_ids) | unique)
				| .updated_at = $now
			)
		end
		' <<< "$data" | _json_write || return 1

	local name mac ip network
	name="$(jaq -r '.hostname // "-"' <<< "$discovered")"
	mac="$(jaq -r '.mac' <<< "$discovered")"
	ip="$(jaq -r '.last_ip // "-"' <<< "$discovered")"
	network="$(jaq -r '.network_name // "-"' <<< "$discovered")"
	print_fn -s "Registered: %s %s %s [%s]" "$name" "$mac" "$ip" "$network"
}

function mac_config {
	case "$1" in
		""|show)
			jaq \
				--arg config_file "$CONFIG_FILE_PATH" \
				--arg selected "$MAC_FILE_PATH" \
				'. + { config_file: $config_file, selected_store_path: $selected }' \
				"$CONFIG_FILE_PATH"
		;;
		path)
			print -- "$CONFIG_FILE_PATH"
		;;
		*)
			print_fn -e "Unknown config subcommand: %s" "$1"
			>&2 print "Usage: $THIS config [path|show]"
			return 1
		;;
	esac
}

function mac_get {
	local query field
	local -a fields
	local f_all

	while (( $# )); do
		case "$1" in
			--all|-a) f_all=1 ;;
			--mac) fields+=(mac) ;;
			--hostname|--name) fields+=(hostname) ;;
			--ip) fields+=(last_ip) ;;
			--network) fields+=(network_name) ;;
			--network-id|--network-ids) fields+=(network_ids) ;;
			--id) fields+=(id) ;;
			--created) fields+=(created_at) ;;
			--updated) fields+=(updated_at) ;;
			--help|-h)
				print -u2 "Usage: $THIS get <QUERY> [--all|--mac|--hostname|--ip|--network|--network-id|--id|--created|--updated]"
				return 0
			;;
			-*)
				print_fn -e "Unknown get option: %s" "$1"
				return 1
			;;
			*)
				[[ -z "$query" ]] || { print_fn -e "Unexpected get argument: %s" "$1"; return 1; }
				query="$1"
			;;
		esac
		shift
	done

	[[ -n "$query" ]] || { print -u2 "Usage: $THIS get <QUERY> [OPTION...]"; return 1; }

	local device
	device="$(_find_device_json "$query")" || {
		print_fn -e "Device '$query' not found, or query is ambiguous."
		return 1
	}

	# Render a single field's value as a string (arrays → newline-joined; null/empty → "-").
	function _render_field {
		jaq -r --arg field "$1" '
			.[$field] as $v
			| if $v == null then "-"
			  elif ($v | type) == "array" then
			      if ($v | length) == 0 then "-" else ($v | join("\n")) end
			  else ($v | tostring)
			  end
		' <<< "$device"
	}

	if [[ -n "$f_all" ]]; then
		local key
		for key in $(jaq -r 'keys_unsorted[]' <<< "$device"); do
			local value="$(_render_field "$key")"
			if [[ "$value" == *$'\n'* ]]; then
				printf '%-13s\n' "$key"
				print -- "$value" | sed 's/^/                /'
			else
				printf '%-13s %s\n' "$key" "$value"
			fi
		done
		unfunction _render_field
		return
	fi

	(( ${#fields} )) || fields=(mac)

	if (( ${#fields} == 1 )); then
		_render_field "${fields[1]}"
	else
		for field in "${fields[@]}"; do
			local value="$(_render_field "$field")"
			if [[ "$value" == *$'\n'* ]]; then
				printf '%-13s\n' "$field"
				print -- "$value" | sed 's/^/                /'
			else
				printf '%-13s %s\n' "$field" "$value"
			fi
		done
	fi

	unfunction _render_field
}

function mac_remove {
	local query="$1"
	[[ -n "$query" ]] || { print -u2 "Usage: $THIS remove <QUERY>"; return 1; }

	local data matches count device mac hostname
	data="$(_json_read)" || return 1
	matches="$(jaq --arg query "$query" "$(_device_filter_jq)" <<< "$data")" || return 1
	count="$(jaq 'length' <<< "$matches")"

	(( count == 1 )) || {
		print_fn -e "Device '$query' not found, or query is ambiguous."
		return 1
	}

	device="$(jaq '.[0]' <<< "$matches")"
	mac="$(jaq -r '.mac' <<< "$device")"
	hostname="$(jaq -r '.hostname // .id // "-"' <<< "$device")"

	jaq --arg mac "$mac" '.devices |= map(select(.mac != $mac))' <<< "$data" | _json_write || return 1
	print_fn -s "Removed: %s (%s)" "$hostname" "$mac"
}

function mac_list {
	local -a f_all
	zparseopts -D -F -K -- {a,-all}=f_all || return 1

	local data connected network_id
	data="$(_json_read)" || return 1

	# Only probe the network when we actually filter by it.
	if (( ! ${#f_all} )); then
		IFS=$'\t' read -r connected network_id < <(
			current_network_json | jaq -r '[.connected, (.id // "")] | @tsv'
		)
	fi

	if [[ -n "$f_all" || "$connected" != "true" ]]; then
		[[ "$connected" != "true" && -z "$f_all" ]] && _warn_no_network
		_print_devices "$data"
	else
		_print_devices "$(jaq --arg network "$network_id" \
			'.devices |= map(select((.network_ids // []) | index($network) != null))' <<< "$data")"
	fi
}

function _device_online {
	local ip="$1" mac="$2"
	[[ -n "$ip" && "$ip" != "null" && "$ip" != "-" ]] || return 1

	command-has ping && ping -c 1 -W 1 "$ip" >/dev/null 2>&1 && return 0

	local seen; seen="$(_mac_from_ip "$ip" 2>/dev/null)"
	[[ -n "$seen" && "$seen" == "$mac" ]]
}

function mac_status {
	local -a f_all
	zparseopts -D -F -K -- {a,-all}=f_all || return 1

	local data connected network_id rows tmpdir row idx
	data="$(_json_read)" || return 1

	# Only probe the network when we actually filter by it.
	if (( ! ${#f_all} )); then
		IFS=$'\t' read -r connected network_id < <(
			current_network_json | jaq -r '[.connected, (.id // "")] | @tsv'
		)
	fi

	if [[ -n "$f_all" || "$connected" != "true" ]]; then
		[[ "$connected" != "true" && -z "$f_all" ]] && _warn_no_network
		rows=("${(@f)$(jaq -r '.devices[] | [.hostname // "-", .mac, .last_ip // "-", .network_name // "-", .id] | @tsv' <<< "$data")}")
	else
		rows=("${(@f)$(jaq -r --arg network "$network_id" \
			'.devices[] | select((.network_ids // []) | index($network) != null) | [.hostname // "-", .mac, .last_ip // "-", .network_name // "-", .id] | @tsv' <<< "$data")}")
	fi

	if (( ! ${#rows} )); then
		print $'STATUS\tHOSTNAME\tMAC\tLAST_IP\tNETWORK\tID' | print_tsv_table
		return 0
	fi

	tmpdir="$(mktemp -d)" || return 1
	idx=0
	for row in "${rows[@]}"; do
		(( idx++ ))
		{
			local hostname mac ip network_name id state
			IFS=$'\t' read -r hostname mac ip network_name id <<< "$row"
			if _device_online "$ip" "$mac"; then
				state="online"
			else
				state="offline"
			fi
			printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$state" "$hostname" "$mac" "$ip" "$network_name" "$id" > "$tmpdir/$idx"
		} &
	done
	wait

	{
		print $'STATUS\tHOSTNAME\tMAC\tLAST_IP\tNETWORK\tID'
		for (( idx = 1; idx <= ${#rows}; idx++ )); do
			[[ -f "$tmpdir/$idx" ]] && < "$tmpdir/$idx"
		done
	} | print_tsv_table
	rm -rf "$tmpdir"
}

function mac_edit {
	local query="$1"
	[[ -n "$query" ]] || {
		print -u2 "Usage: $THIS edit <QUERY> [--hostname HOST] [--id ID] [--ip IP] [--mac MAC] [--network NETWORK_ID|current]"
		return 1
	}
	shift

	local f_hostname f_id f_ip f_mac f_network
	zparseopts -D -F -K -- \
		{n,-hostname}:=f_hostname \
		-name:=f_hostname \
		-id:=f_id \
		-ip:=f_ip \
		-mac:=f_mac \
		-network:=f_network \
		|| return 1

	local data matches count device key when network_id new_id
	data="$(_json_read)" || return 1
	matches="$(jaq --arg query "$query" "$(_device_filter_jq)" <<< "$data")"
	count="$(jaq 'length' <<< "$matches")"

	(( count == 1 )) || {
		print_fn -e "Device '$query' not found, or query is ambiguous."
		return 1
	}

	device="$(jaq '.[0]' <<< "$matches")"
	key="$(jaq -r '.mac' <<< "$device")"

	# No field flags → open just this device in $EDITOR.
	if (( ! ${#f_hostname} && ! ${#f_id} && ! ${#f_ip} && ! ${#f_mac} && ! ${#f_network} )); then
		local tmp editor
		tmp="$(mktemp --suffix=.json)" || return 1
		jaq 'del(._uuid)' <<< "$device" > "$tmp"
		editor="${EDITOR:-${VISUAL:-vi}}"
		"$editor" "$tmp" || { rm -f "$tmp"; return 1; }

		if ! jaq -e 'type == "object" and (.mac | type == "string")' "$tmp" >/dev/null 2>&1; then
			rm -f "$tmp"
			print_fn -e "Edited JSON must be an object with a string 'mac' field; not saving."
			return 1
		fi

		local new_device
		new_device="$(jaq --arg now "$(now)" 'del(._uuid) | .updated_at = $now' "$tmp")"
		rm -f "$tmp"

		jaq --arg key "$key" --argjson new "$new_device" \
			'.devices |= map(if .mac == $key then $new else . end)' <<< "$data" | _json_write || return 1
		print_fn -s "Updated '$query'."
		return
	fi

	# Validate flag values
	if (( ${#f_id} )); then
		new_id="${f_id[-1]}"
		[[ -n "$new_id" ]] || { print_fn -e "Device id cannot be empty."; return 1; }
		if jaq -e --arg key "$key" --arg id "$new_id" \
			'.devices | any(.mac != $key and ((.id // "" | ascii_downcase) == ($id | ascii_downcase)))' <<< "$data" >/dev/null; then
			print_fn -e "Device id already exists: %s" "$new_id"
			return 1
		fi
	fi

	if (( ${#f_mac} )); then
		local new_mac="${f_mac[-1]}"
		mac_verify "$new_mac" || { print_fn -e "Invalid MAC address: %s" "$new_mac"; return 1; }
		f_mac[-1]="$(mac_normalize "$new_mac")"
	fi

	if (( ${#f_network} )); then
		network_id="${f_network[-1]}"
		if [[ "$network_id" == "current" ]]; then
			network_id="$(current_network_json | jaq -r '.id // empty')"
			[[ -n "$network_id" ]] || { _warn_no_network; return 1; }
		fi
	fi

	when="$(now)"
	jaq \
		--arg key "$key" \
		--arg hostname "${f_hostname[-1]}" \
		--arg id "${new_id}" \
		--arg ip "${f_ip[-1]}" \
		--arg mac "${f_mac[-1]}" \
		--arg network "$network_id" \
		--arg now "$when" \
		'
		.devices |= map(if .mac == $key then
			(. + (
				(if $hostname != "" then {hostname:$hostname} else {} end)
				+ (if $id != "" then {id:$id} else {} end)
				+ (if $ip != "" then {last_ip:$ip} else {} end)
				+ (if $mac != "" then {mac:$mac} else {} end)
				+ {updated_at:$now}
			))
			| (if $network != "" then
				.network_ids = (((.network_ids // []) + [$network]) | unique)
			else . end)
		else . end)
		' <<< "$data" | _json_write || return 1

	print_fn -s "Updated '$query'."
}

function mac_wake {
	local query="$1"
	[[ -n "$query" ]] || { print -u2 "Usage: $THIS wake <QUERY>"; return 1; }

	(( ${#WOL_CMD} )) || {
		print_fn -e "Neither 'wol' nor 'wakeonlan' is installed."
		return 127
	}

	local mac
	mac="$(mac_get "$query")" || return 1
	(( verbosity > 0 )) && print_fn -i "Running: %s %s" "${WOL_CMD[*]}" "$mac"
	"${WOL_CMD[@]}" "$mac"
}

function mac_sync {
	local -a f_pull
	zparseopts -D -F -K -- -pull=f_pull || return 1

	[[ -n "$CLOUD_PATH" ]] || {
		print_fn -e "No cloud path configured. Set 'paths.cloud' in %s." "$CONFIG_FILE_PATH"
		return 1
	}

	[[ "${CLOUD_PATH:e}" == "gpg" ]] || {
		print_fn -e "Cloud path '%s' is not a .gpg file; refusing to use unencrypted cloud storage." "$CLOUD_PATH"
		return 1
	}

	if [[ -n "$f_pull" ]]; then
		[[ -f "$CLOUD_PATH" ]] || {
			print_fn -e "Cloud store doesn't exist: %s" "$CLOUD_PATH"
			return 1
		}

		# Decrypt cloud and stage as JSON, validate, then write through to local
		# (which may itself re-encrypt if MAC_FILE_PATH ends in .gpg).
		local decrypted; decrypted="$(jstore_decrypt "$CLOUD_PATH")" || return 1
		if ! jaq -e 'type == "object" and (.devices | type == "array")' >/dev/null 2>&1 <<< "$decrypted"; then
			print_fn -e "Decrypted cloud content is not a valid device store."
			return 1
		fi

		print -r -- "$decrypted" | _json_write || return 1
		print_fn -s "Pulled from cloud: %s → %s" "$CLOUD_PATH" "$MAC_FILE_PATH"
	else
		local data; data="$(_json_read)" || return 1
		print -r -- "$data" | jstore_encrypt "$CLOUD_PATH" || return 1
		print_fn -s "Pushed to cloud: %s → %s" "$MAC_FILE_PATH" "$CLOUD_PATH"
	fi
}

### MAIN

## GPG options (override with WOL_MANAGER_GPG_OPTS)
if [[ -n "$WOL_MANAGER_GPG_OPTS" ]]; then
	GPG_OPTS=(${(z)WOL_MANAGER_GPG_OPTS})
else
	GPG_OPTS=(--yes)
fi

## WoL command resolution (prefer `wol` for Termux compatibility)
if command-has wol; then
	WOL_CMD=(wol)
elif command-has wakeonlan; then
	WOL_CMD=(wakeonlan)
fi

## Setup func opts
local f_help f_verbosity
zparseopts -D -F -K -- \
	{h,-help}=f_help \
	v+=f_verbosity q+=f_verbosity \
	|| exit 1

## Verbosity
f_verbosity="${(j::)f_verbosity//-}"
(( verbosity += (${#f_verbosity//q} - ${#${f_verbosity//v}}) ))

## Help/usage
if [[ "$f_help" ]]; then
	>&2 print -l $usage
	exit 0
fi

## Initialize storage paths (bootstrap from cloud if needed)
_init_paths || exit 1

## Dispatch
if (( ! $# )); then
	mac_list
else
	case $1 in
		add) shift; mac_add "$@" ;;
		config) shift; mac_config "$@" ;;
		get) shift; mac_get "$@" ;;
		remove|rm|delete) shift; mac_remove "$@" ;;
		list|ls) shift; mac_list "$@" ;;
		status|scan) shift; mac_status "$@" ;;
		edit) shift; mac_edit "$@" ;;
		wake|wol) shift; mac_wake "$@" ;;
		sync) shift; mac_sync "$@" ;;
		*)
			>&2 print -l $usage
			exit 1
		;;
	esac
fi
