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

# Loading required libraries
_zsh_source_dir "${ZDOTDIR}/lib/core" "lib/core"
_zsh_source_dir "${ZDOTDIR}/lib/interactive" "lib/interactive"

command-has -av jq ssh || exit 1

readonly -a usage=(
	"Usage: ${THIS} [OPTION...] COMMAND [ARGUMENT...]"
	"\t[-h|--help] : Print this help message"
	"\t[-v] / [-q] : Increase / Decrease verbosity"
	""
	"COMMANDS"
	"\tlist [--tag TAG]                List registered routers"
	"\tadd ID [--host H] [--user U] [--port N] [--tag T]...   Register a router"
	"\tremove ID                       Remove a router"
	"\tedit ID [--host H] [--user U] [--port N] [--id NEW]"
	"\t        [--tag T]... [--untag T]...                    Edit a router (or open in \$EDITOR)"
	"\tssh ID [CMD...]                 Open SSH session, or run a one-shot command"
	"\trun [SELECTORS] [-c CMD]... [--task NAME]...           Batch-run commands across routers"
	"\ttask list                       List available named tasks"
	"\tconfig [path|show|set KEY VAL]  View / edit defaults (prefix, domain, user, port)"
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
			print_fn -e "Unknown task: %s" "$1"
			return 1
		;;
	esac
}

# --- Configuration ---

function _config_default_json {
	jq -n \
		--arg store "$DEFAULT_STORE_PATH" \
		'{
			store_path: $store,
			defaults: {
				user: "root",
				port: 22,
				prefix: "router",
				domain: ".lan"
			}
		}'
}

function _config_ensure {
	[[ -d "$CONFIG_DIR" ]] || mkdir -p "$CONFIG_DIR" || return 1

	if [[ ! -f "$CONFIG_FILE_PATH" ]]; then
		_config_default_json > "$CONFIG_FILE_PATH" || return 1
		return 0
	fi

	if ! jq -e 'type == "object"' "$CONFIG_FILE_PATH" >/dev/null 2>&1; then
		print_fn -e "Invalid config JSON: %s" "$CONFIG_FILE_PATH"
		return 1
	fi

	local tmp; tmp="$(mktemp)" || return 1
	jq \
		--arg store "$DEFAULT_STORE_PATH" \
		'{
			store_path: (.store_path // $store),
			defaults: {
				user:   (.defaults.user   // "root"),
				port:   (.defaults.port   // 22),
				prefix: (.defaults.prefix // "router"),
				domain: (.defaults.domain // ".lan")
			}
		}' "$CONFIG_FILE_PATH" > "$tmp" \
		&& mv "$tmp" "$CONFIG_FILE_PATH" \
		|| { rm -f "$tmp"; return 1; }
}

function _config_value { jq -r "$1 // empty" "$CONFIG_FILE_PATH" }

function _init_paths {
	_config_ensure || return 1
	STORE_PATH="${OWRT_CONFIG_STORE_PATH:-$(_config_value '.store_path')}"
	[[ -n "$STORE_PATH" ]] || STORE_PATH="$DEFAULT_STORE_PATH"
}

# --- Generic helpers ---

function _now { date -Iseconds }

function _json_empty { print '{"version":1,"routers":[]}' }

function _json_read {
	[[ -f "$STORE_PATH" ]] || { _json_empty; return 0 }

	local raw; raw="$(< "$STORE_PATH")" || return 1
	[[ -n "$raw" ]] || { _json_empty; return 0 }

	if ! jq -e 'type == "object" and (.routers | type == "array")' >/dev/null 2>&1 <<< "$raw"; then
		print_fn -e "Router store is not valid JSON: %s" "$STORE_PATH"
		return 1
	fi

	jq '
		.version //= 1
		| .routers //= []
		| .routers |= map(
			.tags //= []
			| .port //= null
			| .user //= null
		)
	' <<< "$raw"
}

function _json_write {
	local tmp; tmp="$(mktemp)" || return 1
	if ! jq -e 'select(type == "object" and (.routers | type == "array")) | .version = 1' > "$tmp"; then
		print_fn -e "Refusing to save invalid router JSON."
		rm -f "$tmp"
		return 1
	fi
	[[ -s "$tmp" ]] || { print_fn -e "Refusing to save empty router JSON."; rm -f "$tmp"; return 1; }

	[[ -d "${STORE_PATH:h}" ]] || mkdir -p "${STORE_PATH:h}" || { rm -f "$tmp"; return 1; }
	mv "$tmp" "$STORE_PATH"
}

function _id_normalize {
	local id="${1:l}"
	id="${id//[^a-z0-9._-]/-}"
	id="${id##-##}"
	id="${id%%-##}"
	print -r -- "$id"
}

function _default_host_for_id {
	local id="$1" prefix domain
	prefix="$(_config_value '.defaults.prefix')"
	domain="$(_config_value '.defaults.domain')"
	[[ "${domain[1]}" == "." || -z "$domain" ]] || domain=".$domain"
	print -r -- "${prefix}${id}${domain}"
}

function _print_tsv_table {
	awk -F '\t' '
	{
		rows[NR] = $0
		if (NF > max_nf) max_nf = NF
		for (i = 1; i <= NF; i++) if (length($i) > width[i]) width[i] = length($i)
	}
	END {
		for (row = 1; row <= NR; row++) {
			split(rows[row], fields, FS)
			for (i = 1; i <= max_nf; i++) {
				value = fields[i]
				if (i == max_nf) printf "%s", value
				else printf "%-*s  ", width[i], value
			}
			printf "\n"
		}
	}'
}

# --- Router lookup ---

function _find_router {
	local id; id="$(_id_normalize "$1")"
	_json_read | jq -e --arg id "$id" \
		'.routers | map(select((.id | ascii_downcase) == $id)) | if length == 1 then .[0] else empty end' \
		2>/dev/null
}

function _resolve_endpoint {
	# Read a router JSON object on stdin, print "user@host port" on stdout.
	local default_user default_port
	default_user="$(_config_value '.defaults.user')"
	default_port="$(_config_value '.defaults.port')"
	jq -r \
		--arg user "$default_user" \
		--arg port "$default_port" \
		'"\(.user // $user)@\(.host) \(.port // ($port | tonumber))"'
}

# --- Commands: registry ---

function owrt_list {
	local f_tag
	zparseopts -D -F -K -- {t,-tag}:=f_tag || return 1
	local tag="${f_tag[-1]}"

	local data; data="$(_json_read)" || return 1

	{
		print $'ID\tHOST\tUSER\tPORT\tTAGS'
		jq -r \
			--arg tag "$tag" \
			--arg default_user "$(_config_value '.defaults.user')" \
			--arg default_port "$(_config_value '.defaults.port')" \
			'.routers
			| (if $tag != "" then map(select((.tags // []) | index($tag))) else . end)
			| if length == 0 then empty else .[] | [
				.id,
				.host,
				(.user // $default_user),
				((.port // ($default_port | tonumber)) | tostring),
				((.tags // []) | join(",") | if . == "" then "-" else . end)
			] | @tsv end' <<< "$data"
	} | _print_tsv_table
}

function owrt_add {
	local id_raw="$1"; shift
	[[ -n "$id_raw" ]] || { print -u2 "Usage: $THIS add ID [--host H] [--user U] [--port N] [--tag T]..."; return 1; }

	local f_host f_user f_port f_tag
	zparseopts -D -F -K -- \
		-host:=f_host \
		-user:=f_user \
		-port:=f_port \
		{t,-tag}+:=f_tag \
		|| return 1

	local id; id="$(_id_normalize "$id_raw")"
	[[ -n "$id" ]] || { print_fn -e "Router id can't be empty."; return 1; }

	local data; data="$(_json_read)" || return 1
	if jq -e --arg id "$id" '.routers | any(.id == $id)' <<< "$data" >/dev/null; then
		print_fn -e "Router already registered: %s (use 'edit')" "$id"
		return 1
	fi

	local host="${f_host[-1]}"
	[[ -n "$host" ]] || host="$(_default_host_for_id "$id")"

	local -a tags=("${(@)f_tag:#(-t|--tag)}")

	local port_arg=null
	if (( ${#f_port} )); then
		[[ "${f_port[-1]}" =~ '^[0-9]+$' ]] || { print_fn -e "Invalid port: %s" "${f_port[-1]}"; return 1; }
		port_arg="${f_port[-1]}"
	fi

	local now; now="$(_now)"
	jq \
		--arg id "$id" \
		--arg host "$host" \
		--arg user "${f_user[-1]}" \
		--argjson port "$port_arg" \
		--argjson tags "$(print -r -- "$tags" | jq -R 'split(" ") | map(select(length>0))')" \
		--arg now "$now" \
		'.routers += [{
			id: $id,
			host: $host,
			user: (if $user != "" then $user else null end),
			port: $port,
			tags: $tags,
			created_at: $now,
			updated_at: $now
		}]' <<< "$data" | _json_write || return 1

	print_fn -s "Registered: %s → %s" "$id" "$host"
}

function owrt_remove {
	local id; id="$(_id_normalize "$1")"
	[[ -n "$id" ]] || { print -u2 "Usage: $THIS remove ID"; return 1; }

	local data; data="$(_json_read)" || return 1
	if ! jq -e --arg id "$id" '.routers | any(.id == $id)' <<< "$data" >/dev/null; then
		print_fn -e "Router not found: %s" "$id"
		return 1
	fi

	jq --arg id "$id" '.routers |= map(select(.id != $id))' <<< "$data" | _json_write || return 1
	print_fn -s "Removed: %s" "$id"
}

function owrt_edit {
	local id_raw="$1"; shift
	[[ -n "$id_raw" ]] || {
		print -u2 "Usage: $THIS edit ID [--host H] [--user U] [--port N] [--id NEW] [--tag T]... [--untag T]..."
		return 1
	}
	local id; id="$(_id_normalize "$id_raw")"

	local f_host f_user f_port f_id f_tag f_untag
	zparseopts -D -F -K -- \
		-host:=f_host \
		-user:=f_user \
		-port:=f_port \
		-id:=f_id \
		{t,-tag}+:=f_tag \
		-untag+:=f_untag \
		|| return 1

	local data router
	data="$(_json_read)" || return 1
	router="$(jq -e --arg id "$id" '.routers | map(select(.id == $id)) | if length == 1 then .[0] else empty end' <<< "$data")" || {
		print_fn -e "Router not found: %s" "$id"
		return 1
	}

	# No flags → $EDITOR
	if (( ! ${#f_host} && ! ${#f_user} && ! ${#f_port} && ! ${#f_id} && ! ${#f_tag} && ! ${#f_untag} )); then
		local tmp editor
		tmp="$(mktemp --suffix=.json)" || return 1
		print -r -- "$router" | jq . > "$tmp"
		editor="${EDITOR:-${VISUAL:-vi}}"
		"$editor" "$tmp" || { rm -f "$tmp"; return 1; }

		if ! jq -e 'type == "object" and (.id | type == "string") and (.host | type == "string")' "$tmp" >/dev/null 2>&1; then
			print_fn -e "Edited JSON must have string 'id' and 'host' fields; not saving."
			rm -f "$tmp"; return 1
		fi

		local new_router; new_router="$(jq --arg now "$(_now)" '.updated_at = $now' "$tmp")"
		rm -f "$tmp"

		jq --arg id "$id" --argjson new "$new_router" \
			'.routers |= map(if .id == $id then $new else . end)' <<< "$data" | _json_write || return 1
		print_fn -s "Updated: %s" "$id"
		return 0
	fi

	# Validate
	local new_id="$id"
	if (( ${#f_id} )); then
		new_id="$(_id_normalize "${f_id[-1]}")"
		[[ -n "$new_id" ]] || { print_fn -e "New id can't be empty."; return 1; }
		if [[ "$new_id" != "$id" ]] && jq -e --arg id "$new_id" '.routers | any(.id == $id)' <<< "$data" >/dev/null; then
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

	jq \
		--arg id "$id" \
		--arg new_id "$new_id" \
		--arg host "${f_host[-1]}" \
		--arg user "${f_user[-1]}" \
		--argjson port "$port_arg" \
		--argjson add "$(print -r -- "$add_tags" | jq -R 'split(" ") | map(select(length>0))')" \
		--argjson del "$(print -r -- "$del_tags" | jq -R 'split(" ") | map(select(length>0))')" \
		--arg now "$(_now)" \
		'.routers |= map(
			if .id == $id then
				.id = $new_id
				| (if $host != "" then .host = $host else . end)
				| (if $user != "" then .user = $user else . end)
				| (if $port != null then .port = $port else . end)
				| .tags = (((.tags // []) + $add) - $del | unique)
				| .updated_at = $now
			else . end
		)' <<< "$data" | _json_write || return 1
	print_fn -s "Updated: %s" "$id"
}

function owrt_config {
	case "$1" in
		""|show)
			jq --arg config_file "$CONFIG_FILE_PATH" \
				'. + { config_file: $config_file }' "$CONFIG_FILE_PATH"
		;;
		path) print -r -- "$CONFIG_FILE_PATH" ;;
		set)
			shift
			local key="$1" value="$2"
			[[ -n "$key" && -n "$value" ]] || { print -u2 "Usage: $THIS config set KEY VALUE"; return 1; }
			case "$key" in
				user|prefix|domain|store_path) ;;
				port)
					[[ "$value" =~ '^[0-9]+$' ]] || { print_fn -e "Port must be numeric."; return 1; }
				;;
				*) print_fn -e "Unknown config key: %s" "$key"; return 1 ;;
			esac
			local tmp; tmp="$(mktemp)" || return 1
			case "$key" in
				store_path)
					jq --arg v "$value" '.store_path = $v' "$CONFIG_FILE_PATH" > "$tmp"
				;;
				port)
					jq --argjson v "$value" '.defaults.port = $v' "$CONFIG_FILE_PATH" > "$tmp"
				;;
				*)
					jq --arg k "$key" --arg v "$value" '.defaults[$k] = $v' "$CONFIG_FILE_PATH" > "$tmp"
				;;
			esac
			[[ -s "$tmp" ]] && mv "$tmp" "$CONFIG_FILE_PATH" || { rm -f "$tmp"; return 1; }
			print_fn -s "Set %s = %s" "$key" "$value"
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
		list)
			local f_names
			zparseopts -D -F -K -- -names=f_names || return 1
			if (( ${#f_names} )); then
				# Machine-readable: name:description per line (for completion).
				local name
				for name in "${(@k)TASK_DESCRIPTIONS}"; do
					printf '%s:%s\n' "$name" "${TASK_DESCRIPTIONS[$name]}"
				done
				return 0
			fi
			{
				print $'TASK\tDESCRIPTION'
				local name
				for name in "${(@k)TASK_DESCRIPTIONS}"; do
					printf '%s\t%s\n' "$name" "${TASK_DESCRIPTIONS[$name]}"
				done
			} | _print_tsv_table
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
	local -a includes excludes tags
	includes=("${(@P)1}")
	excludes=("${(@P)2}")
	tags=("${(@P)3}")
	local all_flag="$4"

	local data; data="$(_json_read)" || return 1

	# Normalize selectors
	local -a inc_norm exc_norm
	local r
	for r in "${includes[@]}"; do inc_norm+=("$(_id_normalize "$r")"); done
	for r in "${excludes[@]}"; do exc_norm+=("$(_id_normalize "$r")"); done

	# Validate includes
	local -a known
	known=("${(@f)$(jq -r '.routers[].id' <<< "$data")}")
	local missing=()
	for r in "${inc_norm[@]}"; do
		[[ -n "$r" && ${known[(I)$r]} -gt 0 ]] || missing+=("$r")
	done
	if (( ${#missing} )); then
		print_fn -e "Unknown router(s): %s" "${(j:, :)missing}"
		return 1
	fi

	# Build JSON arrays via jq -n so empty zsh arrays stay empty in jq (a bare
	# `printf '%s\n' "${empty[@]}"` still emits a blank line, which would turn
	# into [""] and filter out everything).
	local inc_json exc_json tags_json
	inc_json="$(jq -n '$ARGS.positional' --args -- "${inc_norm[@]}")"
	exc_json="$(jq -n '$ARGS.positional' --args -- "${exc_norm[@]}")"
	tags_json="$(jq -n '$ARGS.positional' --args -- "${tags[@]}")"

	jq -r \
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
	} | _print_tsv_table

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

if (( ! $# )); then
	owrt_list
else
	case $1 in
		list|ls)               shift; owrt_list "$@" ;;
		add)                   shift; owrt_add "$@" ;;
		remove|rm|delete)      shift; owrt_remove "$@" ;;
		edit)                  shift; owrt_edit "$@" ;;
		ssh)                   shift; owrt_ssh "$@" ;;
		run)                   shift; owrt_run "$@" ;;
		task)                  shift; owrt_task "$@" ;;
		config)                shift; owrt_config "$@" ;;
		*)
			>&2 print -l $usage
			exit 1
		;;
	esac
fi
