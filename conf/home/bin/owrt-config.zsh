#!/usr/bin/env zsh

emulate -L zsh
setopt pipefail extendedglob

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

command-has -av jaq ssh || exit 1

readonly -a usage=(
	"Usage: ${THIS} [OPTION...] COMMAND [ARGUMENT...]"
	"\t[-h|--help] : Print this help message"
	"\t[-v] / [-q] : Increase / Decrease verbosity"
	""
	"COMMANDS"
	"\tlist [--tag TAG] [--all] [--columns COLS]  List routers (current network only unless --all)"
	"\tadd ID... [--host H] [--user U] [--port N] [--network NAME] [--tag T]...  Register one or more routers"
	"\tremove ID...                    Remove one or more routers"
	"\tedit ID [--host H] [--user U] [--port N] [--id NEW] [--network NAME]"
	"\t        [--tag T]... [--untag T]...                    Edit a router (or open in \$EDITOR)"
	"\tssh ID [CMD...]                 Open SSH session, or run a one-shot command"
	"\tscan [--subnet CIDR] [--add] [--columns COLS]"
	"\t     [--user U] [--port N] [--tag T]...               Discover OpenWRT devices on the LAN"
	"\trun [SELECTORS] [-c CMD]... [--task NAME]...           Batch-run commands across routers"
	"\ttask list [--columns COLS]       List available named tasks"
	"\ttask add NAME [-d DESC] -c CMD [-c CMD]...   Save a task to the config"
	"\ttask rm NAME                    Remove a config-defined task"
	"\tconfig [path|show|set KEY VAL]  View / edit defaults (prefix, domain, user, port)"
	"\t                                 'set network NAME' names the current LAN"
	""
	"COMMAND ALIASES"
	"\tlist=ls,l   add=a   remove=rm,delete,del   edit=ed,e"
	"\tssh=connect,sh   scan=sc   run=r   task=tasks,t   config=cfg,conf"
	""
	"RUN SELECTORS (default: all)"
	"\t-r, --router ID                 Include router (repeatable)"
	"\t-R, --exclude-router ID         Exclude router (repeatable)"
	"\t-t, --tag TAG                   Include routers with TAG (repeatable)"
	"\t    --all                       All registered routers"
	""
	"RUN OPTIONS"
	"\t-c, --command CMD               Raw command to run (repeatable; joined with &&)"
	"\t    --task NAME                 Named preset (repeatable; see 'task list')"
	"\t-p, --parallel                  Run routers in parallel (default: sequential)"
	"\t-i, --interactive               Prompt before run, and between routers in sequential mode"
	"\t-e, --exit-on-error             Stop on first failed router"
	"\t-n, --dry-run                   Print what would run, don't connect"
	""
	"SCAN OPTIONS (requires nmap; curl/avahi-browse enrich detection)"
	"\t    --subnet CIDR               Subnet to scan (default: derived from default route)"
	"\t    --add                       Register newly-found devices (default: dry-run)"
	"\t    --user U / --port N         SSH user/port to store on added devices"
	"\t-t, --tag TAG                   Tag applied to added devices (repeatable)"
)

# --- Storage paths ---
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$THIS_NAME"
readonly CONFIG_FILE_PATH="$CONFIG_DIR/config.json"
readonly DEFAULT_STORE_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/$THIS_NAME/routers.json"

# Set during init
typeset -g STORE_PATH=""
typeset -gi verbosity=0

# --- Named task presets (composed into command lists) ---

typeset -gA TASK_DESCRIPTIONS=(
	wifi-passwd "Prompt for new Wi-Fi password and apply to both radios"
	update-pkgs "Update package index and upgrade installed packages (apk)"
	sysupgrade  "Run owut (attended sysupgrade)"
)

# Human-readable command summary per built-in task (for `task list`).
typeset -gA TASK_BUILTIN_COMMANDS=(
	wifi-passwd "<prompts> && uci set wireless.default_radio{0,1}.key=... && uci commit wireless && wifi"
	update-pkgs "apk update && apk upgrade"
	sysupgrade  "owut upgrade"
)

function _task_cmds {
	# Echo each command on its own line; caller collects them.
	case "$1" in
		wifi-passwd)
			local tmp_passwd new_passwd
			ask -kp "Input new Wi-Fi password" -- -s
			print
			tmp_passwd="$(print -r -- "$REPLY" | sha256sum)"
			new_passwd="$REPLY"
			ask -kp "Confirm Wi-Fi password" -- -s
			print
			if [[ "$tmp_passwd" != "$(print -r -- "$REPLY" | sha256sum)" ]]; then
				print_fn -e "Password mismatch."
				return 1
			fi
			# Single-quote the password for safe transport; reject embedded single quotes.
			if [[ "$new_passwd" == *\'* ]]; then
				print_fn -e "Wi-Fi password cannot contain single quotes."
				return 1
			fi
			print -r -- "uci set wireless.default_radio0.key='$new_passwd'"
			print -r -- "uci set wireless.default_radio1.key='$new_passwd'"
			print -r -- "uci commit wireless"
			print -r -- "wifi"
		;;
		update-pkgs)
			print -- "apk update"
			print -- "apk upgrade"
		;;
		sysupgrade)
			print -- "owut upgrade"
		;;
		*)
			# Fall back to a user-defined task in the config file.
			local custom
			custom="$(jaq -r --arg name "$1" \
				'(.tasks // {})[$name].commands // [] | if type == "array" then .[] else empty end' \
				"$CONFIG_FILE_PATH" 2>/dev/null)"
			if [[ -n "$custom" ]]; then
				print -r -- "$custom"
				return 0
			fi
			print_fn -e "Unknown task: %s" "$1"
			return 1
		;;
	esac
}

# --- Configuration ---

function _config_default_json {
	jaq -n \
		--arg store "$DEFAULT_STORE_PATH" \
		'{
			store_path: $store,
			defaults: {
				user: "root",
				port: 22,
				prefix: "",
				domain: ".lan"
			},
			networks: {},
			tasks: {}
		}'
}

function _config_coerce {
	jaq \
		--arg store "$DEFAULT_STORE_PATH" \
		'{
			store_path: (.store_path // $store),
			defaults: {
				user:   (.defaults.user   // "root"),
				port:   (.defaults.port   // 22),
				prefix: (.defaults.prefix // ""),
				domain: (.defaults.domain // ".lan")
			},
			networks: (.networks // {}),
			tasks: (.tasks // {})
		}'
}

function _config_value { config_value "$CONFIG_FILE_PATH" "$1" }

function _init_paths {
	config_ensure "$CONFIG_FILE_PATH" _config_default_json _config_coerce || return 1
	STORE_PATH="${OWRT_CONFIG_STORE_PATH:-$(_config_value '.store_path')}"
	[[ -n "$STORE_PATH" ]] || STORE_PATH="$DEFAULT_STORE_PATH"
}

# --- Store helpers ---

function _json_read {
	jstore_read "$STORE_PATH" routers '
		.routers |= map(
			.tags //= []
			| .port //= null
			| .user //= null
			| .network //= null
		)
	'
}

function _json_write { jstore_write "$STORE_PATH" routers }

function _id_normalize {
	local id="${1:l}"
	id="${id//[^a-z0-9._-]/-}"
	id="${id##-##}"
	id="${id%%-##}"
	print -r -- "$id"
}

function _default_host_for_id {
	local id="$1" prefix domain core="$1"
	prefix="$(_config_value '.defaults.prefix')"
	domain="$(_config_value '.defaults.domain')"
	[[ "${domain[1]}" == "." || -z "$domain" ]] || domain=".$domain"
	# Avoid double-prefixing/suffixing when the id was given as a full hostname.
	[[ -n "$prefix" && "${core[1,${#prefix}]:l}" == "${prefix:l}" ]] && core="${core[${#prefix}+1,-1]}"
	[[ -n "$domain" && "${core[-${#domain},-1]:l}" == "${domain:l}" ]] && core="${core[1,-${#domain}-1]}"
	print -r -- "${prefix}${core}${domain}"
}

# Resolve --columns selection (Flatpak-style column picker).
# Args:
#   $1 — pipe-separated "name:description" pairs (available columns)
#   $2 — user-supplied value (empty for default, "help" to list, or comma list)
#   $3 — default comma list
# Echoes the validated comma list, or prints help and returns 2.
function _resolve_columns {
	local available_str="$1" user="$2" default="$3"
	local -a available=("${(@s:|:)available_str}")

	if [[ "$user" == "help" || "$user" == "?" ]]; then
		{
			print "Available columns:"
			local pair
			for pair in "${available[@]}"; do
				printf '\t%-14s %s\n' "${pair%%:*}" "${pair#*:}"
			done
			print -- "Default: ${default}"
		} >&2
		return 2
	fi

	local -A names=()
	local pair
	for pair in "${available[@]}"; do
		names[${pair%%:*}]=1
	done

	local picked="${user:-$default}"
	local col
	for col in "${(@s:,:)picked}"; do
		[[ -n "${names[$col]-}" ]] || { print_fn -e "Unknown column: %s (try --columns help)" "$col"; return 1; }
	done
	print -r -- "$picked"
}

# --- Router lookup ---

function _find_router {
	local id; id="$(_id_normalize "$1")"
	_json_read | jaq -e --arg id "$id" \
		'.routers | map(select((.id | ascii_downcase) == $id)) | if length == 1 then .[0] else empty end' \
		2>/dev/null
}

function _resolve_endpoint {
	# Read a router JSON object on stdin, print "user@host port" on stdout.
	local default_user default_port
	default_user="$(_config_value '.defaults.user')"
	default_port="$(_config_value '.defaults.port')"
	jaq -r \
		--arg user "$default_user" \
		--arg port "$default_port" \
		'"\(.user // $user)@\(.host) \(.port // ($port | tonumber))"'
}

# --- Commands: registry ---

function owrt_list {
	local f_tag f_columns f_all
	zparseopts -D -F -K -- \
		{t,-tag}:=f_tag \
		-columns:=f_columns \
		{a,-all}=f_all \
		|| return 1

	local available="id:Router id|host:SSH host|user:Effective SSH user|port:Effective SSH port|tags:Comma-joined tag list|net:Network this router belongs to|created:Created timestamp|updated:Updated timestamp"
	local cols rc
	cols="$(_resolve_columns "$available" "${f_columns[-1]}" "id,host,user,port,tags")"
	rc=$?
	(( rc == 2 )) && return 0
	(( rc == 0 )) || return $rc

	local tag="${f_tag[-1]}"
	local data; data="$(_json_read)" || return 1
	local networks_json; networks_json="$(jaq -c '.networks // {}' "$CONFIG_FILE_PATH" 2>/dev/null)"
	[[ -n "$networks_json" ]] || networks_json="{}"

	# Scope to the current LAN unless --all. When the subnet can't be determined
	# (off-network, or no privilege to read it) there's nothing to filter against,
	# so fall back to showing everything rather than an empty table.
	local -i scoped=0
	local cur_key="" cur_net="-" cur_cidr="" netint=0 block=0
	if (( ! ${#f_all} )); then
		cur_key="$(_scan_network_key)"
		if [[ -n "$cur_key" ]]; then
			scoped=1
			cur_net="$(_network_name "$cur_key")"
			cur_cidr="$(_scan_default_cidr)"
			if [[ -n "$cur_cidr" && "${cur_cidr##*/}" == <0-32> ]]; then
				local -i ci; ci="$(_ip2int "${cur_cidr%%/*}")" 2>/dev/null
				block=$(( 2 ** (32 - ${cur_cidr##*/}) ))
				netint=$(( (ci / block) * block ))
			fi
		else
			print_fn -w "Couldn't determine current network; showing all (use --all to silence, or pass --tag to filter)."
		fi
	fi

	{
		# Header: uppercase column names
		local -a header_cols=("${(@s:,:)cols:u}")
		print -r -- "${(pj:\t:)header_cols}"

		jaq -r \
			--arg tag "$tag" \
			--arg default_user "$(_config_value '.defaults.user')" \
			--arg default_port "$(_config_value '.defaults.port')" \
			--arg cols "$cols" \
			--argjson scoped "$scoped" \
			--arg cur_key "$cur_key" \
			--arg cur_net "$cur_net" \
			--argjson netint "$netint" \
			--argjson block "$block" \
			--argjson networks "$networks_json" \
			'def ip2int: split(".") | map(tonumber) | .[0]*16777216 + .[1]*65536 + .[2]*256 + .[3];
			def in_subnet: ($block > 0)
			    and (type == "string") and test("^[0-9]+(\\.[0-9]+){3}$")
			    and ((ip2int / $block | floor) == ($netint / $block | floor));
			.routers
			| (if $tag != "" then map(select((.tags // []) | index($tag))) else . end)
			| (if $scoped == 1 then
			      map(select((.host | in_subnet) or (.network != null and .network == $cur_key)))
			   else . end)
			| if length == 0 then empty
			  else
			    ($cols | split(",")) as $picked
			    | .[]
			    | . as $r
			    | {
			        id:      ($r.id // "-"),
			        host:    ($r.host // "-"),
			        user:    ($r.user // $default_user // "-"),
			        port:    (($r.port // ($default_port | tonumber)) | tostring),
			        tags:    (($r.tags // []) | join(",") | if . == "" then "-" else . end),
			        net:     (if ($r.host | in_subnet) then $cur_net
			                  elif ($r.network != null) then ($networks[$r.network] // $r.network)
			                  else "-" end),
			        created: ($r.created_at // "-"),
			        updated: ($r.updated_at // "-")
			      } as $row
			    | [ $picked[] as $c | $row[$c] ] | @tsv
			  end' <<< "$data"
	} | print_tsv_table
}

function owrt_add {
	# zparseopts stops at the first operand, so parse in passes: consume leading
	# options, grab one id, repeat — this lets flags appear in any position.
	# Tags are drained each pass because -K keeps only the last repeatable match.
	local f_host f_user f_port f_tag f_network
	local -a id_args=() tags=()
	while (( $# )); do
		f_tag=()
		zparseopts -D -F -K -- \
			-host:=f_host \
			-user:=f_user \
			-port:=f_port \
			-network:=f_network \
			{t,-tag}+:=f_tag \
			|| return 1
		tags+=("${(@)f_tag:#(-t|--tag)}")
		(( $# )) || break
		id_args+=("$1"); shift
	done
	(( ${#id_args} )) || { print -u2 "Usage: $THIS add ID... [--host H] [--user U] [--port N] [--network NAME] [--tag T]..."; return 1; }

	# --host is per-device, so it only makes sense for a single id; other flags
	# (user/port/tag) apply to every id in the batch.
	if (( ${#f_host} && ${#id_args} > 1 )); then
		print_fn -e "Option --host can only be used when adding a single router."
		return 1
	fi

	local port_arg=null
	if (( ${#f_port} )); then
		[[ "${f_port[-1]}" =~ '^[0-9]+$' ]] || { print_fn -e "Invalid port: %s" "${f_port[-1]}"; return 1; }
		port_arg="${f_port[-1]}"
	fi

	local tags_json; tags_json="$(jaq -n '$ARGS.positional' --args -- "${tags[@]}")"

	# Hosts added by id are usually hostnames, not IPs, so the subnet test can't
	# catch them — the network stamp is their only scoping signal. Default it to
	# the current LAN (overridable with --network NAME) so a freshly added router
	# shows up in the scoped list right away.
	local network
	if (( ${#f_network} )); then
		network="$(_network_resolve_key "${f_network[-1]}")"
	else
		network="$(_scan_network_key)"
	fi

	local data; data="$(_json_read)" || return 1

	local now; now="$(now)"
	local -a added=()
	local raw id host
	for raw in "${id_args[@]}"; do
		id="$(_id_normalize "$raw")"
		[[ -n "$id" ]] || { print_fn -w "Skipping empty id: %s" "$raw"; continue; }
		if jaq -e --arg id "$id" '.routers | any(.id == $id)' <<< "$data" >/dev/null; then
			print_fn -w "Already registered, skipping: %s (use 'edit')" "$id"
			continue
		fi

		host="${f_host[-1]}"
		[[ -n "$host" ]] || host="$(_default_host_for_id "$id")"

		data="$(jaq \
			--arg id "$id" \
			--arg host "$host" \
			--arg user "${f_user[-1]}" \
			--argjson port "$port_arg" \
			--argjson tags "$tags_json" \
			--arg network "$network" \
			--arg now "$now" \
			'.routers += [{
				id: $id,
				host: $host,
				user: (if $user != "" then $user else null end),
				port: $port,
				tags: $tags,
				network: (if $network != "" then $network else null end),
				created_at: $now,
				updated_at: $now
			}]' <<< "$data")" || return 1
		added+=("$id")
		print_fn -s "Registered: %s → %s" "$id" "$host"
	done

	(( ${#added} )) || { print_fn -e "No routers added."; return 1; }
	print -r -- "$data" | _json_write || return 1
}

function owrt_remove {
	local -a id_args=("$@")
	(( ${#id_args} )) || { print -u2 "Usage: $THIS remove ID..."; return 1; }

	local data; data="$(_json_read)" || return 1

	local -a removed=()
	local raw id
	for raw in "${id_args[@]}"; do
		id="$(_id_normalize "$raw")"
		[[ -n "$id" ]] || { print_fn -w "Skipping empty id: %s" "$raw"; continue; }
		if jaq -e --arg id "$id" '.routers | any(.id == $id)' <<< "$data" >/dev/null; then
			data="$(jaq --arg id "$id" '.routers |= map(select(.id != $id))' <<< "$data")" || return 1
			removed+=("$id")
		else
			print_fn -w "Not found, skipping: %s" "$id"
		fi
	done

	(( ${#removed} )) || { print_fn -e "No routers removed."; return 1; }
	print -r -- "$data" | _json_write || return 1
	print_fn -s "Removed: %s" "${(j:, :)removed}"
}

function owrt_edit {
	local id_raw="$1"; shift
	[[ -n "$id_raw" ]] || {
		print -u2 "Usage: $THIS edit ID [--host H] [--user U] [--port N] [--id NEW] [--network NAME] [--tag T]... [--untag T]..."
		return 1
	}
	local id; id="$(_id_normalize "$id_raw")"

	local f_host f_user f_port f_id f_tag f_untag f_network
	zparseopts -D -F -K -- \
		-host:=f_host \
		-user:=f_user \
		-port:=f_port \
		-id:=f_id \
		-network:=f_network \
		{t,-tag}+:=f_tag \
		-untag+:=f_untag \
		|| return 1

	local data router
	data="$(_json_read)" || return 1
	router="$(jaq -e --arg id "$id" '.routers | map(select(.id == $id)) | if length == 1 then .[0] else empty end' <<< "$data")" || {
		print_fn -e "Router not found: %s" "$id"
		return 1
	}

	# No flags → $EDITOR
	if (( ! ${#f_host} && ! ${#f_user} && ! ${#f_port} && ! ${#f_id} && ! ${#f_tag} && ! ${#f_untag} && ! ${#f_network} )); then
		local tmp editor
		tmp="$(mktemp --suffix=.json)" || return 1
		print -r -- "$router" | jaq . > "$tmp"
		editor="${EDITOR:-${VISUAL:-vi}}"
		"$editor" "$tmp" || { rm -f "$tmp"; return 1; }

		if ! jaq -e 'type == "object" and (.id | type == "string") and (.host | type == "string")' "$tmp" >/dev/null 2>&1; then
			print_fn -e "Edited JSON must have string 'id' and 'host' fields; not saving."
			rm -f "$tmp"; return 1
		fi

		local new_router; new_router="$(jaq --arg now "$(now)" '.updated_at = $now' "$tmp")"
		rm -f "$tmp"

		jaq --arg id "$id" --argjson new "$new_router" \
			'.routers |= map(if .id == $id then $new else . end)' <<< "$data" | _json_write || return 1
		print_fn -s "Updated: %s" "$id"
		return 0
	fi

	# Validate
	local new_id="$id"
	if (( ${#f_id} )); then
		new_id="$(_id_normalize "${f_id[-1]}")"
		[[ -n "$new_id" ]] || { print_fn -e "New id can't be empty."; return 1; }
		if [[ "$new_id" != "$id" ]] && jaq -e --arg id "$new_id" '.routers | any(.id == $id)' <<< "$data" >/dev/null; then
			print_fn -e "Router id already exists: %s" "$new_id"
			return 1
		fi
	fi

	local port_arg=null
	if (( ${#f_port} )); then
		[[ "${f_port[-1]}" =~ '^[0-9]+$' ]] || { print_fn -e "Invalid port: %s" "${f_port[-1]}"; return 1; }
		port_arg="${f_port[-1]}"
	fi

	local -a add_tags=("${(@)f_tag:#(-t|--tag)}")
	local -a del_tags=("${(@)f_untag:#--untag}")

	# --network NAME pins the router to a network; --network '' clears it.
	local network="" set_network=0
	if (( ${#f_network} )); then
		set_network=1
		[[ -n "${f_network[-1]}" ]] && network="$(_network_resolve_key "${f_network[-1]}")"
	fi

	jaq \
		--arg id "$id" \
		--arg new_id "$new_id" \
		--arg host "${f_host[-1]}" \
		--arg user "${f_user[-1]}" \
		--argjson port "$port_arg" \
		--argjson set_network "$set_network" \
		--arg network "$network" \
		--argjson add "$(print -r -- "$add_tags" | jaq -R 'split(" ") | map(select(length>0))')" \
		--argjson del "$(print -r -- "$del_tags" | jaq -R 'split(" ") | map(select(length>0))')" \
		--arg now "$(now)" \
		'.routers |= map(
			if .id == $id then
				.id = $new_id
				| (if $host != "" then .host = $host else . end)
				| (if $user != "" then .user = $user else . end)
				| (if $port != null then .port = $port else . end)
				| (if $set_network == 1 then .network = (if $network != "" then $network else null end) else . end)
				| .tags = (((.tags // []) + $add) - $del | unique)
				| .updated_at = $now
			else . end
		)' <<< "$data" | _json_write || return 1
	print_fn -s "Updated: %s" "$id"
}

function owrt_config {
	case "$1" in
		""|show)
			jaq --arg config_file "$CONFIG_FILE_PATH" \
				'. + { config_file: $config_file }' "$CONFIG_FILE_PATH"
		;;
		path) print -r -- "$CONFIG_FILE_PATH" ;;
		set)
			shift
			local key="$1" value="$2"
			[[ -n "$key" && -n "$value" ]] || { print -u2 "Usage: $THIS config set KEY VALUE"; return 1; }
			local net_key=""
			case "$key" in
				user|prefix|domain|store_path) ;;
				port)
					[[ "$value" =~ '^[0-9]+$' ]] || { print_fn -e "Port must be numeric."; return 1; }
				;;
				network)
					# Name whichever LAN we're on right now, keyed by its fingerprint.
					net_key="$(_scan_network_key)"
					[[ -n "$net_key" ]] || { print_fn -e "Couldn't determine current network to name."; return 1; }
				;;
				*) print_fn -e "Unknown config key: %s" "$key"; return 1 ;;
			esac
			local tmp; tmp="$(mktemp)" || return 1
			case "$key" in
				store_path)
					jaq --arg v "$value" '.store_path = $v' "$CONFIG_FILE_PATH" > "$tmp"
				;;
				port)
					jaq --argjson v "$value" '.defaults.port = $v' "$CONFIG_FILE_PATH" > "$tmp"
				;;
				network)
					jaq --arg k "$net_key" --arg v "$value" \
						'.networks = ((.networks // {}) | .[$k] = $v)' "$CONFIG_FILE_PATH" > "$tmp"
				;;
				*)
					jaq --arg k "$key" --arg v "$value" '.defaults[$k] = $v' "$CONFIG_FILE_PATH" > "$tmp"
				;;
			esac
			[[ -s "$tmp" ]] && mv "$tmp" "$CONFIG_FILE_PATH" || { rm -f "$tmp"; return 1; }
			if [[ "$key" == network ]]; then
				print_fn -s "Named network %s = %s" "$net_key" "$value"
			else
				print_fn -s "Set %s = %s" "$key" "$value"
			fi
		;;
		*)
			print_fn -e "Unknown config subcommand: %s" "$1"
			print -u2 "Usage: $THIS config [show|path|set KEY VALUE]"
			return 1
		;;
	esac
}

function owrt_task {
	local sub="${1:-list}"
	shift 2>/dev/null
	case "$sub" in
		add)
			local name="$1"; shift 2>/dev/null
			[[ -n "$name" ]] || { print -u2 "Usage: $THIS task add NAME [--description DESC] -c CMD [-c CMD]..."; return 1; }

			local f_desc
			local -a f_cmds
			zparseopts -D -F -K -- \
				{d,-description}:=f_desc \
				{c,-command}+:=f_cmds \
				|| return 1

			local -a cmds=("${(@)f_cmds:#(-c|--command)}")
			(( ${#cmds} )) || { print_fn -e "At least one command (-c CMD) is required."; return 1; }

			local desc="${f_desc[-1]}"

			local tmp; tmp="$(mktemp)" || return 1
			jaq \
				--arg name "$name" \
				--arg desc "$desc" \
				--argjson cmds "$(jaq -n '$ARGS.positional' --args -- "${cmds[@]}")" \
				'.tasks //= {}
				 | .tasks[$name] = (
				     {commands: $cmds}
				     + (if $desc != "" then {description: $desc} else {} end)
				 )' "$CONFIG_FILE_PATH" > "$tmp" \
				&& mv "$tmp" "$CONFIG_FILE_PATH" \
				|| { rm -f "$tmp"; return 1; }

			print_fn -s "Added task: %s (%d command%s)" "$name" "${#cmds}" "$( (( ${#cmds} == 1 )) || print s )"
		;;
		list|ls)
			local f_names f_columns
			zparseopts -D -F -K -- -names=f_names -columns:=f_columns || return 1

			local available="name:Task name|description:Task description|source:built-in or config|commands:Joined command list"
			local cols rc
			cols="$(_resolve_columns "$available" "${f_columns[-1]}" "name,description,source,commands")"
			rc=$?
			(( rc == 2 )) && return 0
			(( rc == 0 )) || return $rc

			# Merge built-in tasks with config-defined tasks; config overrides on name collision.
			local -A all_desc all_cmds
			local name
			for name in "${(@k)TASK_DESCRIPTIONS}"; do
				all_desc[$name]="${TASK_DESCRIPTIONS[$name]}"
				all_cmds[$name]="${TASK_BUILTIN_COMMANDS[$name]-}"
			done

			local -a entries
			entries=("${(@f)$(jaq -r '.tasks // {} | to_entries[] | "\(.key)\t\(.value.description // "(no description)")\t\((.value.commands // []) | join(" && "))"' \
				"$CONFIG_FILE_PATH" 2>/dev/null)}")
			local entry desc cmds
			for entry in "${entries[@]}"; do
				[[ -n "$entry" ]] || continue
				name="${entry%%$'\t'*}"
				local rest="${entry#*$'\t'}"
				desc="${rest%%$'\t'*}"
				cmds="${rest#*$'\t'}"
				all_desc[$name]="$desc"
				all_cmds[$name]="$cmds"
			done

			if (( ${#f_names} )); then
				# Machine-readable: name:description per line (for completion).
				for name in "${(@k)all_desc}"; do
					printf '%s:%s\n' "$name" "${all_desc[$name]}"
				done
				return 0
			fi

			local -a chosen=("${(@s:,:)cols}")

			{
				local -a header_cols=("${(@)chosen:u}")
				print -r -- "${(pj:\t:)header_cols}"

				local col val source
				for name in "${(@k)all_desc}"; do
					if [[ -n "${TASK_DESCRIPTIONS[$name]-}" ]]; then
						source="built-in"
					else
						source="config"
					fi
					local -a row=()
					for col in "${chosen[@]}"; do
						case "$col" in
							name)        val="$name" ;;
							description) val="${all_desc[$name]:--}" ;;
							source)      val="$source" ;;
							commands)    val="${all_cmds[$name]:--}" ;;
						esac
						row+=("$val")
					done
					print -r -- "${(pj:\t:)row}"
				done
			} | print_tsv_table
		;;
		rm|remove|delete)
			local name="$1"
			[[ -n "$name" ]] || { print -u2 "Usage: $THIS task rm NAME"; return 1; }
			if [[ -n "${TASK_DESCRIPTIONS[$name]-}" ]]; then
				print_fn -e "Cannot remove built-in task: %s" "$name"
				return 1
			fi
			if ! jaq -e --arg name "$name" '(.tasks // {}) | has($name)' "$CONFIG_FILE_PATH" >/dev/null 2>&1; then
				print_fn -e "Task not found in config: %s" "$name"
				return 1
			fi
			local tmp; tmp="$(mktemp)" || return 1
			jaq --arg name "$name" 'del(.tasks[$name])' "$CONFIG_FILE_PATH" > "$tmp" \
				&& mv "$tmp" "$CONFIG_FILE_PATH" \
				|| { rm -f "$tmp"; return 1; }
			print_fn -s "Removed task: %s" "$name"
		;;
		*) print_fn -e "Unknown task subcommand: %s" "$sub"; return 1 ;;
	esac
}

function owrt_ssh {
	local id_raw="$1"; shift
	[[ -n "$id_raw" ]] || { print -u2 "Usage: $THIS ssh ID [CMD...]"; return 1; }

	local router; router="$(_find_router "$id_raw")" || {
		print_fn -e "Router not found: %s" "$id_raw"
		return 1
	}

	local endpoint port user_host
	endpoint="$(print -r -- "$router" | _resolve_endpoint)"
	user_host="${endpoint% *}"
	port="${endpoint##* }"

	if (( $# )); then
		ssh -p "$port" "$user_host" "$@"
	else
		ssh -t -p "$port" "$user_host"
	fi
}

# --- Batch run ---

function _select_routers {
	# Args: parsed selector arrays via name reference.
	# Echoes selected router ids (one per line) in registry order.
	# NOTE: locals must NOT share names with the caller's arrays — zsh's (@P)
	# name-reference resolves in the current scope first, so a local `includes`
	# would shadow the caller's array and silently match nothing (→ no filter).
	local -a _includes _excludes _tags
	_includes=("${(@P)1}")
	_excludes=("${(@P)2}")
	_tags=("${(@P)3}")
	local all_flag="$4"

	local data; data="$(_json_read)" || return 1

	# Normalize selectors
	local -a inc_norm exc_norm
	local r
	for r in "${_includes[@]}"; do inc_norm+=("$(_id_normalize "$r")"); done
	for r in "${_excludes[@]}"; do exc_norm+=("$(_id_normalize "$r")"); done

	# Validate includes
	local -a known
	known=("${(@f)$(jaq -r '.routers[].id' <<< "$data")}")
	local missing=()
	for r in "${inc_norm[@]}"; do
		[[ -n "$r" && ${known[(I)$r]} -gt 0 ]] || missing+=("$r")
	done
	if (( ${#missing} )); then
		print_fn -e "Unknown router(s): %s" "${(j:, :)missing}"
		return 1
	fi

	# Build JSON arrays via jaq -n so empty zsh arrays stay empty in jaq (a bare
	# `printf '%s\n' "${empty[@]}"` still emits a blank line, which would turn
	# into [""] and filter out everything).
	local inc_json exc_json tags_json
	inc_json="$(jaq -n '$ARGS.positional' --args -- "${inc_norm[@]}")"
	exc_json="$(jaq -n '$ARGS.positional' --args -- "${exc_norm[@]}")"
	tags_json="$(jaq -n '$ARGS.positional' --args -- "${_tags[@]}")"

	jaq -r \
		--argjson inc "$inc_json" \
		--argjson exc "$exc_json" \
		--argjson tags "$tags_json" \
		--arg all "$all_flag" \
		'
		.routers
		| if ($inc | length) > 0 then map(select(.id as $i | $inc | index($i))) else . end
		| if ($tags | length) > 0 then map(select((.tags // []) as $t | $tags | any(. as $tag | $t | index($tag)))) else . end
		| map(select(.id as $i | ($exc | index($i)) | not))
		| .[].id
		' <<< "$data"
}

function _run_one {
	# Streams to a per-router log file; writes exit code into <log>.exit.
	local id="$1" cmd="$2" logfile="$3" dry_run="$4"

	local router endpoint port user_host
	router="$(_find_router "$id")" || { print 127 > "${logfile}.exit"; return; }
	endpoint="$(print -r -- "$router" | _resolve_endpoint)"
	user_host="${endpoint% *}"
	port="${endpoint##* }"

	if (( dry_run )); then
		print -r -- "[dry-run] ssh -p $port $user_host -- $cmd" > "$logfile"
		print 0 > "${logfile}.exit"
		return
	fi

	local -i ec
	ssh \
		-o BatchMode=no \
		-o ConnectTimeout=10 \
		-o StrictHostKeyChecking=accept-new \
		-p "$port" \
		"$user_host" \
		"$cmd" \
		</dev/null \
		>"$logfile" 2>&1
	ec=$?
	print -- "$ec" > "${logfile}.exit"
}

function owrt_run {
	local -a f_routers f_ex_routers f_tags f_cmds f_tasks
	local -a f_all f_parallel f_interactive f_error f_dry
	zparseopts -D -F -K -- \
		{r,-router}+:=f_routers \
		{R,-exclude-router}+:=f_ex_routers \
		{t,-tag}+:=f_tags \
		{c,-command}+:=f_cmds \
		-task+:=f_tasks \
		-all=f_all \
		{p,-parallel}=f_parallel \
		{i,-interactive}=f_interactive \
		{e,-exit-on-error}=f_error \
		{n,-dry-run}=f_dry \
		|| return 1

	local -a includes=("${(@)f_routers:#(-r|--router)}")
	local -a excludes=("${(@)f_ex_routers:#(-R|--exclude-router)}")
	local -a tags=("${(@)f_tags:#(-t|--tag)}")
	local -a raw_cmds=("${(@)f_cmds:#(-c|--command)}")
	local -a tasks=("${(@)f_tasks:#--task}")

	# Build command list: tasks (expanded) then explicit -c commands
	local -a cmds=()
	local task line
	for task in "${tasks[@]}"; do
		local -a expanded=()
		expanded=("${(@f)$(_task_cmds "$task")}") || return 1
		(( ${#expanded} )) || { print_fn -e "Task produced no commands: %s" "$task"; return 1; }
		cmds+=("${expanded[@]}")
	done
	cmds+=("${raw_cmds[@]}")

	(( ${#cmds} )) || { print_fn -e "No commands provided (use -c CMD or --task NAME)."; return 1; }

	# Default to all routers if no selector
	if (( ! ${#includes} && ! ${#tags} && ! ${#f_all} )); then
		f_all=(--all)
	fi

	local -a router_ids
	router_ids=("${(@f)$(_select_routers includes excludes tags ${#f_all})}") || return 1
	router_ids=("${(@)router_ids:#}")
	(( ${#router_ids} )) || { print_fn -e "No routers matched."; return 1; }

	# Compose final command string
	local joined="${(j: && :)cmds}"

	local -i dry=${#f_dry} parallel=${#f_parallel} interactive=${#f_interactive} exit_on_error=${#f_error}

	# Plan summary
	print "Plan:"
	printf '\tRouters (%d): %s\n' "${#router_ids}" "${(j:, :)router_ids}"
	printf '\tMode: %s%s\n' "$( (( parallel )) && print parallel || print sequential )" \
		"$( (( dry )) && print -- ' (dry-run)' )"
	printf '\tCommand: %s\n' "$joined"

	if (( interactive )); then
		ask -Bp "Proceed?" -d "N"
		(( ! $? )) || return 1
	fi

	local tmpdir; tmpdir="$(mktemp -d)" || return 1
	local -A exit_codes
	local -a failures=()
	local -i aborted=0

	if (( parallel )); then
		local id pid
		local -a pids
		for id in "${router_ids[@]}"; do
			_run_one "$id" "$joined" "$tmpdir/$id" "$dry" &
			pids+=($!)
			print_fn -i "Started: %s" "$id"
		done
		wait $pids
		for id in "${router_ids[@]}"; do
			local ec; ec="$(< "$tmpdir/$id.exit")"
			exit_codes[$id]=$ec
			if (( ec != 0 )); then
				failures+=("$id")
				print_fn -e "FAIL %s (exit %d)" "$id" "$ec"
			else
				print_fn -s "OK   %s" "$id"
			fi
			(( verbosity > 0 )) && [[ -s "$tmpdir/$id" ]] && {
				print -- "--- $id output ---"
				< "$tmpdir/$id"
			}
		done
	else
		local id ec
		for id in "${router_ids[@]}"; do
			print_fn -i "→ %s" "$id"
			_run_one "$id" "$joined" "$tmpdir/$id" "$dry"
			ec="$(< "$tmpdir/$id.exit")"
			exit_codes[$id]=$ec
			# Stream the captured output now
			[[ -s "$tmpdir/$id" ]] && < "$tmpdir/$id"
			if (( ec != 0 )); then
				failures+=("$id")
				print_fn -e "FAIL %s (exit %d)" "$id" "$ec"
				if (( exit_on_error )); then
					aborted=1
					break
				fi
			else
				print_fn -s "OK   %s" "$id"
			fi
			# Prompt between routers when interactive and not on last
			if (( interactive )) && [[ "$id" != "${router_ids[-1]}" ]]; then
				ask -Bp "Continue?" -d "N"
				(( ! $? )) || { aborted=1; break; }
			fi
		done
	fi

	# Summary
	print
	print "Summary:"
	{
		print $'STATUS\tROUTER\tEXIT'
		local row_id row_ec row_state
		for row_id in "${router_ids[@]}"; do
			row_ec="${exit_codes[$row_id]-}"
			if [[ -z "$row_ec" ]]; then
				row_state="skipped"
				row_ec="-"
			elif (( row_ec == 0 )); then
				row_state="ok"
			else
				row_state="fail"
			fi
			printf '%s\t%s\t%s\n' "$row_state" "$row_id" "$row_ec"
		done
	} | print_tsv_table

	if (( ${#failures} )); then
		print
		print "Failure details:"
		local fail_id
		for fail_id in "${failures[@]}"; do
			print -- "--- $fail_id ---"
			[[ -s "$tmpdir/$fail_id" ]] && < "$tmpdir/$fail_id" || print -- "(no output)"
		done
	fi

	rm -rf "$tmpdir"

	(( ${#failures} == 0 && ! aborted ))
}

# --- Network identity ---
#
# Routers roam: the same store holds devices from several LANs, so the registry
# is scoped to "where am I now". A network is fingerprinted by a stable *key* —
# the gateway's MAC (countless LANs share 192.168.1.0/24, the MAC does not),
# falling back to the subnet's network address when ARP is mute. Membership is a
# mix of two signals: a router whose host IP sits inside the current subnet, or
# one explicitly stamped with the current key (covers hosts stored by name).

function _ip2int {
	local -a o=("${(@s:.:)1}")
	(( ${#o} == 4 )) || return 1
	print -r -- $(( (o[1] << 24) | (o[2] << 16) | (o[3] << 8) | o[4] ))
}

function _scan_network_key {
	# Echo a stable fingerprint for the current LAN — its network address, e.g.
	# 192.168.1.138/24 -> 192.168.1.0/24 — or nothing when off-network.
	#
	# A gateway MAC would be collision-proof (many LANs reuse 192.168.1.0/24), but
	# this device drops the wlan default route for seconds at a time, so neither
	# the gateway nor its ARP entry is dependable. The interface address always
	# is. If two of your LANs genuinely share a subnet, disambiguate them with
	# `add --network NAME` / `config set network NAME`.
	local cidr ipint bits block netint
	cidr="$(_scan_default_cidr)" || return 1
	bits="${cidr##*/}"
	[[ "$bits" == <0-32> ]] || { print -r -- "$cidr"; return 0 }
	ipint="$(_ip2int "${cidr%%/*}")" || { print -r -- "$cidr"; return 0 }
	block=$(( 2 ** (32 - bits) ))
	netint=$(( (ipint / block) * block ))
	print -r -- "$(( (netint >> 24) & 255 )).$(( (netint >> 16) & 255 )).$(( (netint >> 8) & 255 )).$(( netint & 255 ))/$bits"
}

function _network_name {
	# Human label for a key (from config .networks), or the key itself if unnamed.
	local key="$1" name
	[[ -n "$key" ]] || return 1
	# Keys are MAC/CIDR — only [0-9a-f:./] — so safe to splice into the filter.
	name="$(_config_value ".networks[\"${key}\"]")"
	print -r -- "${name:-$key}"
}

function _network_resolve_key {
	# Map a user-supplied network name back to its key; pass an unknown value
	# (assumed to already be a key) through unchanged. So routers are always
	# stamped with the stable key, however the user referred to the network.
	local v="$1" key
	[[ -n "$v" ]] || return 1
	key="$(jaq -r --arg v "$v" \
		'.networks // {} | to_entries | map(select(.value == $v)) | (.[0].key // $v)' \
		"$CONFIG_FILE_PATH" 2>/dev/null)"
	print -r -- "${key:-$v}"
}

# --- Network scan ---

typeset -g _NET_PROBE_FILE="${TMPDIR:-/tmp}/owrt-netprobe.$$"

function _net_run {
	# Run a shell command string with the privilege Android needs to read
	# netlink. On Termux the unprivileged app can't bind a netlink socket
	# ("Cannot bind netlink socket: Permission denied"), so queries are funnelled
	# through an escalation shell (Shizuku's rish, then su). Everywhere else the
	# plain binary works, so we run it directly.
	local cmd="$1"
	if whatami android; then
		local esc out
		for esc in rish su; do
			command-has "$esc" || continue
			out="$("$esc" -c "$cmd" 2>/dev/null)"
			[[ -n "$out" ]] && { print -r -- "$out"; return 0 }
		done
		return 1
	fi
	eval "$cmd" 2>/dev/null
}

function _net_probe {
	# One privileged snapshot of routes + addresses, cached in a per-process file
	# so the half-dozen things we derive from it (gateway, local CIDR, network
	# key) cost a single escalation. The cache is a file (not a global) so it
	# survives the command-substitution subshells the callers run in; MAIN removes
	# it on exit.
	#
	# This device's netlink state flickers: the wlan default route and even the
	# wlan interface address intermittently drop out of `ip` output for a beat
	# (mobile-data/wlan handover churn). So we retry until a usable LAN address
	# (non-loopback, non-/32) shows up, rather than trust a single read. No
	# section markers: route ("default via ...") and address (" inet ") lines are
	# self-distinguishing, and an `echo` marker between commands proved unreliable
	# through the escalation shell.
	[[ -s "$_NET_PROBE_FILE" ]] && { cat -- "$_NET_PROBE_FILE"; return 0 }
	local out; local -i i=0
	while (( i < 6 )); do
		out="$(_net_run '
			ip -o route show table all default
			ip -o -f inet addr show')"
		if print -r -- "$out" | awk '
			$3 == "inet" && $4 !~ /^127\./ && $4 !~ /\/32$/ {ok = 1}
			END {exit !ok}'; then
			break
		fi
		(( ++i < 6 )) && sleep 0.3
	done
	[[ -n "$out" ]] || return 1
	print -r -- "$out" > "$_NET_PROBE_FILE"
	print -r -- "$out"
}

function _scan_default_cidr {
	# Derive the local IPv4 CIDR from the interface backing the default route.
	# We look across all routing tables (Android keeps per-network policy tables
	# rather than a single main-table default) and pick the first IPv4 default
	# that goes *via* a gateway. That excludes mobile-data / point-to-point links
	# (rmnet, dummy0), which are scope-link /32s with nothing on-LAN to scan.
	local probe iface cidr
	probe="$(_net_probe)" || return 1
	iface="$(print -r -- "$probe" | awk '
		$0 ~ /^default via [0-9]+\./ {for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')"
	# addr lines (-o): "47: wlan0    inet 192.168.1.138/24 brd ..." → $2 iface, $4 cidr
	[[ -n "$iface" ]] && cidr="$(print -r -- "$probe" | awk -v ifc="$iface" '
		$2 == ifc && $3 == "inet" {print $4; exit}')"
	# Fallback: Android transiently drops the wlan default route, so derive the
	# LAN straight from interface addresses — the first global IPv4 that's neither
	# loopback nor a /32 (mobile-data links are point-to-point /32s).
	[[ -n "$cidr" ]] || cidr="$(print -r -- "$probe" | awk '
		$3 == "inet" && $4 !~ /^127\./ && $4 !~ /\/32$/ {print $4; exit}')"
	[[ -n "$cidr" ]] || return 1
	print -r -- "$cidr"
}

function _scan_live_hosts {
	# Args: CIDR. Echo "IP<TAB>HOSTNAME<TAB>PORTSCSV" for each up host that has
	# at least one of ports 22/80/443 open. PTR hostname filled in by nmap.
	# -n skips nmap's own reverse DNS: it would query the system resolver for
	# every host, which stalls on the router's private PTR zone. We resolve
	# names ourselves against the gateway (_scan_ptr), so the PTR field is moot.
	local cidr="$1" line ip hostname portfield ports tok
	for line in "${(@f)$(nmap -n -p 22,80,443 --open -oG - "$cidr" 2>/dev/null)}"; do
		[[ "$line" == Host:\ * && "$line" == *Ports:* ]] || continue
		ip="${${(s: :)line}[2]}"
		hostname=""
		[[ "$line" =~ '\(([^)]+)\)' ]] && hostname="${match[1]}"
		portfield="${line#*Ports: }"
		portfield="${portfield%%	*}"
		ports=""
		for tok in "${(@s:, :)portfield}"; do
			[[ "$tok" == *open* ]] && ports="${ports:+$ports,}${tok%%/*}"
		done
		print -r -- "$ip	$hostname	$ports"
	done
}

function _scan_gateway {
	_net_probe | awk '$0 ~ /^default via [0-9]+\./ {print $3; exit}'
}

function _scan_ptr {
	# Reverse-lookup IP directly against the LAN gateway's DNS. The system
	# resolver (e.g. systemd-resolved) often can't answer the router's private
	# PTR zone, so nmap sees only IPs — but the router itself knows the names.
	# Echo a bare hostname, or nothing.
	local ip="$1" gw="$2" name=
	[[ -n "$gw" ]] || return 0
	if command-has dig; then
		name="$(dig +short +time=2 +tries=1 -x "$ip" @"$gw" 2>/dev/null | head -1)"
	elif command-has host; then
		name="$(host -W2 "$ip" "$gw" 2>/dev/null | awk '/domain name pointer/ {print $NF; exit}')"
	elif command-has nslookup; then
		name="$(nslookup "$ip" "$gw" 2>/dev/null | awk '/name =/ {print $NF; exit}')"
	fi
	print -r -- "${name%.}"
}

function _scan_mdns_map {
	# Best-effort. Echo "IP<TAB>HOSTNAME" lines from resolved mDNS records.
	command-has avahi-browse || return 0
	avahi-browse -atrp 2>/dev/null | awk -F';' '$1=="=" && $3=="IPv4" {print $8"\t"$7}'
}

function _scan_probe_http {
	# Fingerprint OpenWRT from its web stack. Follow redirects (-L) and include
	# both headers and body (-i): stock OpenWRT often redirects http→https and
	# exposes no 'Server: uhttpd', so the only tell is LuCI in the served page.
	command-has curl || return 1
	# Only probe schemes whose port nmap reported open, so we never wait out a
	# connect timeout on a closed port.
	local ip="$1" ports="$2" scheme out
	local -a schemes=()
	[[ ",$ports," == *,80,* ]]  && schemes+=(http)
	[[ ",$ports," == *,443,* ]] && schemes+=(https)
	for scheme in "${schemes[@]}"; do
		out="$(curl -s -k -L -i --max-time 3 "$scheme://$ip/" 2>/dev/null)" || continue
		[[ -n "$out" ]] || continue
		print -r -- "$out" | grep -qiE 'luci|openwrt|uhttpd|dropbear|x-luci' && return 0
	done
	return 1
}

function _scan_probe_ssh {
	# Fingerprint OpenWRT by reading its release files. Key-auth only and
	# non-interactive, so a host without a usable key fails silently.
	local ip="$1" user out
	user="$(_config_value '.defaults.user')"
	out="$(ssh \
		-o BatchMode=yes \
		-o ConnectTimeout=3 \
		-o StrictHostKeyChecking=accept-new \
		-o PreferredAuthentications=publickey \
		"${user:+$user@}$ip" \
		'cat /etc/openwrt_release /etc/os-release 2>/dev/null' \
		</dev/null 2>/dev/null)"
	[[ "${out:l}" == *openwrt* ]]
}

function _scan_fingerprint {
	# Probe a single host (HTTP/SSH/mDNS) and, if it looks like OpenWRT, resolve
	# its name and write "IP<TAB>HOSTNAME<TAB>DETECT" to $out. Designed to run in
	# the background — it touches no shared shell state, only its own out file.
	emulate -L zsh
	local ip="$1" ptr="$2" ports="$3" gw="$4" mdns_host="$5" out="$6"
	local -a sig=()
	[[ ",$ports," == *,80,* || ",$ports," == *,443,* ]] && _scan_probe_http "$ip" "$ports" && sig+=(http)
	[[ ",$ports," == *,22,* ]] && _scan_probe_ssh "$ip" && sig+=(ssh)
	[[ -n "$mdns_host" && "${mdns_host:l}" == *openwrt* ]] && sig+=(mdns)
	(( ${#sig} )) || return 0

	# Gateway DNS is authoritative for the LAN; fall back to nmap PTR, then mDNS.
	# Drop the synthetic "_gateway" name systemd-resolved hands out.
	local hostname
	hostname="$(_scan_ptr "$ip" "$gw")"
	[[ -n "$hostname" ]] || hostname="${ptr%.}"
	[[ -n "$hostname" ]] || hostname="$mdns_host"
	[[ "$hostname" == _gateway ]] && hostname=""

	print -r -- "$ip	$hostname	${(j:,:)sig}" > "$out"
}

function owrt_scan {
	local f_subnet f_columns f_user f_port f_tag f_add
	zparseopts -D -F -K -- \
		-subnet:=f_subnet \
		-columns:=f_columns \
		-user:=f_user \
		-port:=f_port \
		{t,-tag}+:=f_tag \
		-add=f_add \
		|| return 1

	command-has -av nmap || { print_fn -e "scan requires nmap."; return 1; }

	local cidr="${f_subnet[-1]}"
	[[ -n "$cidr" ]] || cidr="$(_scan_default_cidr)" || {
		print_fn -e "Couldn't determine local subnet; pass --subnet CIDR."
		return 1
	}
	local gw; gw="$(_scan_gateway)"
	# Stamp discovered routers with the current network so they stay grouped even
	# after you've roamed off this LAN. When a custom --subnet is scanned we may
	# not be on it, so the key can be empty — that's fine, IP membership still
	# scopes them while you're here.
	local network; network="$(_scan_network_key)"

	local available="ip:Discovered IP|host:SSH host (the IP)|hostname:Resolved hostname|id:Proposed router id|detect:Matched fingerprints|status:new or existing"
	local cols rc
	cols="$(_resolve_columns "$available" "${f_columns[-1]}" "id,host,hostname,detect,status")"
	rc=$?
	(( rc == 2 )) && return 0
	(( rc == 0 )) || return $rc

	local port_arg=null
	if (( ${#f_port} )); then
		[[ "${f_port[-1]}" =~ '^[0-9]+$' ]] || { print_fn -e "Invalid port: %s" "${f_port[-1]}"; return 1; }
		port_arg="${f_port[-1]}"
	fi
	local -a tags=("${(@)f_tag:#(-t|--tag)}")
	local tags_json; tags_json="$(jaq -n '$ARGS.positional' --args -- "${tags[@]}")"
	local -i do_add=${#f_add}

	local data; data="$(_json_read)" || return 1

	local -a chosen=("${(@s:,:)cols}")
	local -a rows=()
	local -i found=0 add_count=0 scan_rc=0

	# The slow work — avahi (a few seconds), nmap, and per-host probes — runs
	# under a spinner so the terminal shows progress instead of looking frozen.
	# Confirmed devices print above the live spinner as they are found.
	{
	spinner_start "Scanning ${cidr} (nmap + fingerprint) ..."

	# Loop-locals declared once here: re-running `local NAME` each iteration
	# would make zsh echo "NAME=value" (typeset prints already-set params).
	local line ip rest ptr ports hostname host_field id_src id dev_state detect col f ml
	local -a row live
	local -A mdns
	local tmpdir; tmpdir="$(mktemp -d)" || scan_rc=1

	# Phase 1: discover live hosts (nmap), then fingerprint them in parallel.
	# The probes are network-bound (HTTP/SSH/DNS timeouts), so running them
	# concurrently turns an O(hosts) wall-clock into roughly O(hosts/MAXJOBS).
	if (( ! scan_rc )); then
		# mDNS browse has a fixed ~5s settle, so run it in the background
		# (dotfile, excluded from the result glob) overlapped with the nmap
		# sweep rather than paying both serially.
		_scan_mdns_map > "$tmpdir/.mdns" &
		local -i mdns_pid=$!

		live=("${(@f)$(_scan_live_hosts "$cidr")}")

		wait $mdns_pid
		for ml in "${(@f)$(< "$tmpdir/.mdns")}"; do
			[[ -n "$ml" ]] || continue
			mdns[${ml%%	*}]="${ml#*	}"
		done

		local -i idx=0 inflight=0
		local -ri MAXJOBS=24
		for line in "${live[@]}"; do
			[[ -n "$line" ]] || continue
			ip="${line%%	*}"
			rest="${line#*	}"
			ptr="${rest%%	*}"
			ports="${rest#*	}"
			_scan_fingerprint "$ip" "$ptr" "$ports" "$gw" "${mdns[$ip]-}" "$tmpdir/$(printf '%05d' $idx)" &
			(( idx++, inflight++ ))
			(( inflight < MAXJOBS )) || { wait; inflight=0 }
		done
		wait

		# Phase 2: collect hits in IP order (zero-padded filenames sort to nmap's
		# order) and update the store serially, so dedup and writes stay race-free.
		for f in "$tmpdir"/*(N.); do
			[[ -s "$f" ]] || continue
			line="$(< "$f")"
			ip="${line%%	*}"
			rest="${line#*	}"
			hostname="${rest%%	*}"
			detect="${rest#*	}"
			found+=1

			# id derives from the hostname's leading label; host stays the IP so
			# SSH connects even when .lan names don't resolve forward here.
			if [[ -n "$hostname" ]]; then
				id_src="${${hostname%.local}%%.*}"
			else
				id_src="$ip"
			fi
			host_field="$ip"
			id="$(_id_normalize "$id_src")"

			dev_state="$(jaq -r --arg id "$id" --arg host "$host_field" --arg ip "$ip" \
				'if (.routers | any(.id == $id or .host == $host or .host == $ip)) then "existing" else "new" end' <<< "$data")"

			if [[ "$dev_state" == new ]]; then
				# Append in-memory so later same-scan duplicates dedupe too; only
				# persisted when --add is set.
				data="$(jaq \
					--arg id "$id" \
					--arg host "$host_field" \
					--argjson port "$port_arg" \
					--arg user "${f_user[-1]}" \
					--argjson tags "$tags_json" \
					--arg network "$network" \
					--arg now "$(now)" \
					'.routers += [{
						id: $id,
						host: $host,
						user: (if $user != "" then $user else null end),
						port: $port,
						tags: $tags,
						network: (if $network != "" then $network else null end),
						created_at: $now,
						updated_at: $now
					}]' <<< "$data")" || { scan_rc=1; break; }
				add_count+=1
			fi

			print_fn -s "Found %s (%s) [%s] (%s)" "${hostname:-$ip}" "$ip" "$dev_state" "$detect"
			row=()
			for col in "${chosen[@]}"; do
				case "$col" in
					ip)       row+=("$ip") ;;
					host)     row+=("$host_field") ;;
					hostname) row+=("${hostname:--}") ;;
					id)       row+=("$id") ;;
					detect)   row+=("$detect") ;;
					status)   row+=("$dev_state") ;;
				esac
			done
			rows+=("${(pj:\t:)row}")
		done
	fi
	} always {
		spinner_stop 0 ''
		[[ -n "$tmpdir" ]] && rm -rf "$tmpdir"
	}

	(( scan_rc == 0 )) || return 1

	if (( ! found )); then
		print_fn -w "No OpenWRT devices found on %s." "$cidr"
		return 0
	fi

	{
		local -a header=("${(@)chosen:u}")
		print -r -- "${(pj:\t:)header}"
		print -rl -- "${rows[@]}"
	} | print_tsv_table

	if (( do_add && add_count )); then
		print -r -- "$data" | _json_write || return 1
		print_fn -s "Registered %d new device(s)." "$add_count"
	elif (( add_count )); then
		print_fn -i "%d new device(s) found; re-run with --add to register them." "$add_count"
	else
		print_fn -i "All discovered devices already registered."
	fi
}

### MAIN

## Setup func opts
local f_help f_verbosity
zparseopts -D -F -K -- \
	{h,-help}=f_help \
	v+=f_verbosity q+=f_verbosity \
	|| exit 1

f_verbosity="${(j::)f_verbosity//-}"
(( verbosity += (${#f_verbosity//q} - ${#${f_verbosity//v}}) ))

if [[ "$f_help" ]]; then
	>&2 print -l $usage
	exit 0
fi

_init_paths || exit 1

# Drop the cached network probe (see _net_probe) when the script exits.
TRAPEXIT() { [[ -n "$_NET_PROBE_FILE" ]] && rm -f -- "$_NET_PROBE_FILE" }

if (( ! $# )); then
	owrt_list
else
	case $1 in
		list|ls|l)                 shift; owrt_list "$@" ;;
		add|a)                     shift; owrt_add "$@" ;;
		remove|rm|delete|del)      shift; owrt_remove "$@" ;;
		edit|ed|e)                 shift; owrt_edit "$@" ;;
		ssh|connect|sh)            shift; owrt_ssh "$@" ;;
		scan|sc)                   shift; owrt_scan "$@" ;;
		run|r)                     shift; owrt_run "$@" ;;
		task|tasks|t)              shift; owrt_task "$@" ;;
		config|cfg|conf)           shift; owrt_config "$@" ;;
		*)
			>&2 print -l $usage
			exit 1
		;;
	esac
fi
