#!/usr/bin/env zsh
# Apply (or audit) btrfs nodatacow on database-bearing docker volumes.
# Triggered by nodatacow.path on changes under /var/lib/docker/volumes,
# and by nodatacow-audit.timer weekly with --audit to alert on drift.
# +C only takes effect on empty files; new files inherit. Already-populated
# volumes that lack +C need a manual stop/copy/start re-convert.
emulate -L zsh
setopt pipe_fail extended_glob null_glob no_unset

local VOLROOT=/var/lib/docker/volumes
local OVERRIDES=/usr/local/etc/nodatacow/overrides.list
local TOKEN_FILE=/usr/local/etc/nodatacow/ntfy-token
local NTFY_URL=http://127.0.0.1:2586
local TOPIC=nodatacow

local MODE=apply
[[ "${1-}" == "--audit" ]] && MODE=audit

local NAME_RE='maria|mysql|postgres|pgdata|redis|portainer|(^|[-_])db([-_]|$)'
local SQLITE_HEX=53514c69746520666f726d6174203300

overrides() { grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$OVERRIDES" 2>/dev/null }

has_db_marker() {
	# Check _data and one level below for known DB fingerprints.
	local d=$1 p f
	for p in $d $d/*(N/); do
		[[ -e $p/ibdata1 || -e $p/aria_log_control || -e $p/PG_VERSION ]] && return 0
		local -a ibl=($p/ib_logfile*(N))
		(( ${#ibl} )) && return 0
		# SQLite magic header on any regular file at this depth.
		# Hex compare avoids shell command substitution stripping the trailing NUL.
		for f in $p/*(N.); do
			[[ "$(head -c16 -- $f 2>/dev/null | xxd -p)" == $SQLITE_HEX ]] && return 0
		done
	done
	return 1
}

is_db_volume() {
	local name=$1 data=$2
	overrides | grep -qxF "$name" && return 0
	[[ "${name:l}" =~ $NAME_RE ]] && return 0
	has_db_marker "$data"
}

local -a drift
local vol name data attrs
for vol in $VOLROOT/*(N/); do
	name=${vol:t}
	data=$vol/_data
	[[ -d $data ]] || continue
	[[ "$(command stat -f -c %T $data 2>/dev/null)" == btrfs ]] || continue
	is_db_volume "$name" "$data" || continue

	attrs="$(lsattr -d $data 2>/dev/null | awk '{print $1}')"
	[[ $attrs == *C* ]] && continue

	if [[ $MODE == audit ]]; then
		drift+=$name
	else
		if chattr +C $data 2>/dev/null; then
			logger -t nodatacow "applied +C to volume ${name}"
		else
			logger -t nodatacow -p user.warning "failed +C on volume ${name}"
		fi
	fi
done

if [[ $MODE == audit ]]; then
	if (( ${#drift} )); then
		local msg="DB volume(s) reverted to CoW, re-run nodatacow conversion: ${drift[*]}"
		logger -t nodatacow -p user.warning "$msg"
		if [[ -r $TOKEN_FILE ]]; then
			curl -s -m 10 \
				-H "Authorization: Bearer $(<$TOKEN_FILE)" \
				-H "Title: nodatacow audit - action needed" \
				-H "Priority: high" -H "Tags: warning,floppy_disk" \
				-d "$msg" "$NTFY_URL/$TOPIC" >/dev/null \
				|| logger -t nodatacow "ntfy post failed"
		fi
	else
		logger -t nodatacow "audit OK - all detected DB volumes are nodatacow"
	fi
fi

exit 0
