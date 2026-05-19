# Config-config_path helpers for JSON-backed config under $XDG_CONFIG_HOME/<tool>/.

# config_value FILE FILTER → jq filter applied to FILE, empty string on null.
function config_value {
	local config_path="$1" filter="$2"
	jq -r "${filter} // empty" "$config_path"
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

	if ! jq -e 'type == "object"' "$config_path" >/dev/null 2>&1; then
		print_fn -e "Invalid config JSON: %s" "$config_path"
		return 1
	fi

	local tmp; tmp="$(mktemp)" || return 1
	"$coerce_fn" < "$config_path" > "$tmp" || { rm -f "$tmp"; return 1; }
	if cmp -s "$tmp" "$config_path"; then
		rm -f "$tmp"
	else
		mv "$tmp" "$config_path" || { rm -f "$tmp"; return 1; }
	fi
}
