# Config-config_path helpers for JSON-backed config under $XDG_CONFIG_HOME/<tool>/.

# config_value FILE FILTER → jaq filter applied to FILE, empty string on null.
function config_value {
	local config_path="$1" filter="$2"
	jaq -r "${filter} // empty" "$config_path"
}

# config_ensure FILE DEFAULT_FN COERCE_FN
#   DEFAULT_FN — called with no args to emit the initial JSON when FILE absent.
#   COERCE_FN  — reads existing JSON on stdin, emits migrated JSON on stdout.
#                Used to fill in new defaults / drop removed keys.
function config_ensure {
	local config_path="$1" default_fn="$2" coerce_fn="$3"

	[[ -d "${config_path:h}" ]] || mkdir -p "${config_path:h}" || return 1

	if [[ ! -f "$config_path" ]]; then
		"$default_fn" > "$config_path" || return 1
		return 0
	fi

	local current coerced
	current="$(<"$config_path")"
	coerced="$("$coerce_fn" <<< "$current")" || {
		print_fn -e "Invalid config JSON: %s" "$config_path"
		return 1
	}
	[[ "$current" == "$coerced" ]] || print -r -- "$coerced" > "$config_path"
}
