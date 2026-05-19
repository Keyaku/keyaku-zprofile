# Versioned-JSON store: one top-level array under a named key, optionally
# wrapped in GPG symmetric encryption when the store_path ends in `.gpg`.
#
# Empty store shape: {"version":1,"<key>":[]}
#
# GPG-aware variants honour these caller-set globals:
#   GPG_OPTS  — array of base options passed to every gpg invocation.
#   verbosity — integer; >0 keeps gpg's status output, otherwise --quiet.

function jstore_empty {
	local key="$1"
	jaq -n --arg key "$key" '{version: 1, ($key): []}'
}

# jstore_decrypt PATH → JSON text on stdout. Pass-through for plain files;
# `gpg --decrypt` for *.gpg. No schema validation.
function jstore_decrypt {
	local store_path="$1"
	[[ -f "$store_path" ]] || return 1

	if [[ "${store_path:e}" == "gpg" ]]; then
		local err; err="$(mktemp)" || return 1
		local -a gpg_args=("${GPG_OPTS[@]}" --decrypt --output -)
		(( ${verbosity:-0} > 0 )) || gpg_args+=(--quiet)
		if ! gpg "${gpg_args[@]}" "$store_path" 2>"$err"; then
			print_fn -e "Unable to decrypt '%s'." "$store_path"
			[[ -s "$err" ]] && sed 's/^/gpg: /' "$err" >&2
			rm -f "$err"
			return 1
		fi
		rm -f "$err"
	else
		# `print -r --` + `$(<store_path)` is the zsh-native pass-through; avoids
		# depending on /bin/cat being on $PATH inside subshells.
		print -r -- "$(<$store_path)"
	fi
}

# jstore_encrypt PATH < json-on-stdin → write to PATH (atomic via tmp + mv).
# *.gpg paths get gpg --symmetric; others get a plain mv.
function jstore_encrypt {
	local store_path="$1"
	[[ -d "${store_path:h}" ]] || mkdir -p "${store_path:h}" || return 1

	local tmp; tmp="$(mktemp)" || return 1
	cat > "$tmp" || { rm -f "$tmp"; return 1; }
	[[ -s "$tmp" ]] || { rm -f "$tmp"; return 1; }

	if [[ "${store_path:e}" == "gpg" ]]; then
		local enc; enc="$(mktemp)" || { rm -f "$tmp"; return 1; }
		local -a gpg_args=("${GPG_OPTS[@]}" --symmetric --output "$enc")
		(( ${verbosity:-0} > 0 )) || gpg_args+=(--quiet)
		gpg "${gpg_args[@]}" "$tmp" || { rm -f "$tmp" "$enc"; return 1; }
		mv "$enc" "$store_path"
		rm -f "$tmp"
	else
		mv "$tmp" "$store_path"
	fi
}

# jstore_read PATH KEY [COERCE_FILTER] → validated JSON on stdout.
#
# Reads PATH (decrypting if .gpg), checks it's an object with .KEY as an
# array, normalizes `.version` and `.KEY`, then applies COERCE_FILTER (a jq
# expression) for per-record migration / defaulting. Missing/empty store_path →
# empty store. Schema mismatch → error (caller can detect legacy formats by
# bypassing this and using jstore_decrypt directly).
function jstore_read {
	local store_path="$1" key="$2" coerce="${3:-.}"

	[[ -f "$store_path" ]] || { jstore_empty "$key"; return 0 }

	local raw; raw="$(jstore_decrypt "$store_path")" || return 1
	[[ -n "$raw" ]] || { jstore_empty "$key"; return 0 }

	local out
	if ! out="$(jaq --arg key "$key" "
		if type != \"object\" or (.[\$key] | type) != \"array\"
		then error(\"shape\") else . end
		| .version //= 1
		| .[\$key] //= []
		| $coerce
	" <<< "$raw" 2>/dev/null)"; then
		print_fn -e "Store is not valid JSON or missing .%s array: %s" "$key" "$store_path"
		return 1
	fi
	printf '%s\n' "$out"
}

# jstore_write PATH KEY < json-on-stdin → write atomically.
# Validates shape (object with .KEY array) and stamps .version=1 before
# encrypt/move. Refuses empty or malformed input.
function jstore_write {
	local store_path="$1" key="$2"

	local validated; validated="$(jaq -e --arg key "$key" \
		'select(type == "object" and (.[$key] | type == "array")) | .version = 1')" || {
		print_fn -e "Refusing to save invalid JSON (missing .%s array)." "$key"
		return 1
	}

	print -r -- "$validated" | jstore_encrypt "$store_path"
}
