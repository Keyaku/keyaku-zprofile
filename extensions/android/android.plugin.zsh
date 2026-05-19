if ! whatami Android; then
	### Session type (X11, Wayland) configuration
	if [[ -z "${XDG_SESSION_TYPE}" ]] && command-has loginctl; then
		export XDG_SESSION_TYPE="$(loginctl show-session $(awk '/tty/ {print $1}' <(loginctl)) -p Type | awk -F= '{print $2}')"
	fi

# if actually on Android (Termux)
elif (( ${+TERMUX_VERSION} )) && [[ "${TERMUX__PREFIX:P}" == "/data/data/com.termux/files/usr" ]]; then
	# Silence Message of the Day (motd)
	if [[ -f "$HOME"/../usr/etc/motd ]]; then
		mv "$HOME"/../usr/etc/motd{,.old}
	fi
	# Apply rish (Shizuku) configuration
	if [[ -d "$HOME"/.termux/rish.d && -f "$HOME"/.termux/rish.d/rish ]]; then
		(rish_exec=($(echo "$HOME"/.termux/rish.d/rish(.NxE)))
			(( 0 == ${#rish_exec} )) && chmod ug+x "$HOME"/.termux/rish.d/rish
		)
		if [[ ! -L "$HOME"/.local/bin/rish ]]; then
			rm -f "$HOME"/.local/bin/rish
			ln -s "$HOME"/.termux/rish.d/rish "$HOME"/.local/bin/rish
		fi
		[[ "${RISH_APPLICATION_ID}" == "com.termux" ]] || export RISH_APPLICATION_ID="com.termux"
	fi

	function termux_backup {
		local -a usage=(
			"Usage: $0 [-o OUTPUT]"
			"Back up Termux \$HOME and \$PREFIX to a gzipped tarball."
			""
			"  -o OUTPUT  output path (default: \$HOME/storage/downloads/termux-backup.tar.gz)"
		)
		local -a o_output
		zparseopts -D -F -K -- \
			o:=o_output	\
			{h,-help}=o_help \
		|| {
			>&2 print -l $usage
			return 2
		}
		if (( ${#o_help} )) || ! check_argc $# 0 0; then
			>&2 print -l $usage
			return $(( ${#o_help} ? 0 : 2 ))
		fi
		local -r output="${o_output[2]:-${HOME}/storage/downloads/termux-backup.tar.gz}"
		local -r src="/data/data/com.termux/files"
		if [[ ! -d "${src}" ]]; then
			print_fn -e "Termux files directory not found: ${src}"
			return 1
		fi
		local -r outdir="${output:h}"
		if (( 0 == ${#o_output} )); then
			# Default path: validate that ~/storage/downloads is the
			# symlink created by `termux-setup-storage`, not a stray dir.
			if [[ ! -e "${HOME}/storage" ]]; then
				print_fn -e "${HOME}/storage missing. Run 'termux-setup-storage' first"
				return 1
			elif [[ ! -L "${HOME}/storage/downloads" ]]; then
				print_fn -e "${HOME}/storage/downloads is not a symlink. Storage permission likely not granted"
				return 1
			elif [[ ! -d "${HOME}/storage/downloads" ]]; then
				print_fn -e "${HOME}/storage/downloads symlink target is unreachable"
				return 1
			fi
		else
			if [[ ! -d "${outdir}" ]]; then
				print_fn -e "Output directory does not exist: ${outdir}"
				return 1
			fi
		fi
		if [[ ! -w "${outdir}" ]]; then
			print_fn -e "Output directory is not writable: ${outdir}"
			return 1
		elif [[ -e "${output}" && ! -w "${output}" ]]; then
			print_fn -e "Output file exists and is not writable: ${output}"
			return 1
		fi
		print_fn -i "Backing up Termux to ${output}"
		if ! tar -zcf "${output}" -C "${src}" ./home ./usr; then
			local -ri rc=$?
			print_fn -e "tar failed (exit ${rc})"
			return ${rc}
		fi
		print_fn -s "Backup written to ${output}"

		# Write a standalone POSIX-sh restore script next to the tarball so
		# the backup is self-contained, no dependency on this zsh setup.
		local -r script="${output%.tar.gz}-restore.sh"
		local -r backup_basename="${output:t}"
		if ! cat >"${script}" <<-EOF
			#!/data/data/com.termux/files/usr/bin/sh
			# Restore a Termux backup created by termux_backup.
			# Run from inside Termux. Destructive: replaces files under
			# /data/data/com.termux/files/{home,usr}.
			set -eu
			BACKUP="\${1:-\$(dirname "\$0")/${backup_basename}}"
			DEST="/data/data/com.termux/files"
			[ -f "\$BACKUP" ] || { echo "Backup not found: \$BACKUP" >&2; exit 1; }
			[ -d "\$DEST" ] || { echo "Termux files dir missing: \$DEST" >&2; exit 1; }
			printf 'Restore %s into %s? Type yes to confirm: ' "\$BACKUP" "\$DEST"
			read -r ans
			[ "\$ans" = yes ] || { echo "Aborted." >&2; exit 1; }
			exec tar -zxf "\$BACKUP" -C "\$DEST" --recursive-unlink --preserve-permissions
		EOF
		then
			print_fn -w "Could not write companion restore script to ${script}"
		else
			chmod +x "${script}" 2>/dev/null
			print_fn -s "Restore script written to ${script}"
		fi
		print_fn -s "To restore, run: ${script}"
	}

	function termux_pkgmgr {
		local -ra usage=(
			"Usage: $0 [-c|-l] [TARGET]"
			"Inspect or stage a Termux package-manager bootstrap switch."
			""
			"  -c, --current   Print current package manager and exit"
			"  -l, --list      List supported managers"
			"  -h, --help      Show this help"
			""
			"TARGET            One of: apt, pacman. Interactive prompt if omitted."
			""
			"Switching downloads the target bootstrap zip into ~/storage/downloads,"
			"verifies it where possible, and prints manual extraction instructions."
			"This function NEVER modifies \$PREFIX. Replacing a live \$PREFIX from"
			"within a shell that lives in it is unsafe."
		)
		local -a o_current o_list o_help
		zparseopts -D -F -K -- \
			{c,-current}=o_current \
			{l,-list}=o_list \
			{h,-help}=o_help \
		|| { >&2 print -l $usage; return 2 }
		if (( ${#o_help} )); then >&2 print -l $usage; return 0; fi

		# Repo per manager. Asset name convention: bootstrap-<arch>.zip
		local -A managers=(
			[apt]="termux/termux-packages"
			[pacman]="termux-pacman/termux-packages"
		)

		# Detect what is actually installed (db presence beats binary presence;
		# a stray pacman binary on an apt system shouldn't flip detection).
		local current=""
		if [[ -d "${PREFIX}/var/lib/pacman/local" ]]; then
			current="pacman"
		elif [[ -f "${PREFIX}/var/lib/dpkg/status" ]]; then
			current="apt"
		fi

		if (( ${#o_list} )); then
			print -l ${(ko)managers}
			return 0
		elif (( ${#o_current} )); then
			[[ -n "$current" ]] && { print "$current"; return 0 }
			print_fn -w "No known package manager detected"
			return 1
		fi

		check_argc $# 0 1 || { >&2 print -l $usage; return 2 }

		# Hard guard: must be inside Termux.
		if ! whatami Android || [[ "${TERMUX__PREFIX:P}" != "/data/data/com.termux/files/usr" ]]; then
			print_fn -e "${funcstack[1]} only runs inside Termux"
			return 1
		fi

		# Pick target: arg, else interactive (plain select; no GUI on SSH).
		local target="${1:-}"
		if [[ -z "$target" ]]; then
			print_fn -i "Current package manager: ${current:-unknown}"
			local -a choices=(${(ko)managers})
			local m reply i=1
			for m in $choices; do
				print -u2 "  $i) $m"
				((i++))
			done
			printf 'Select target [1-%d]: ' ${#choices} >&2
			read -r reply
			if [[ "$reply" != <-> ]] || (( reply < 1 || reply > ${#choices} )); then
				print_fn -e "Invalid selection"
				return 2
			fi
			target="${choices[$reply]}"
		fi

		if [[ -z "${managers[$target]+x}" ]]; then
			print_fn -e "Unknown target: $target (try: ${(ko)managers})"
			return 2
		fi

		if [[ "$target" == "$current" ]]; then
			print_fn -i "Already using $target. Nothing to do."
			return 0
		fi

		# Resolve architecture.
		local arch
		case "$(uname -m)" in
		aarch64)  arch=aarch64 ;;
		arm*)     arch=arm ;;
		x86_64)   arch=x86_64 ;;
		i*86)     arch=i686 ;;
		*)        print_fn -e "Unsupported architecture: $(uname -m)"; return 1 ;;
		esac

		# Storage symlink: validated by termux-setup-storage; bail if missing
		# so we never write to a path the user can't actually reach from outside.
		if [[ ! -L "${HOME}/storage/downloads" ]]; then
			print_fn -e "${HOME}/storage/downloads missing. Run 'termux-setup-storage' first"
			return 1
		fi

		# Need curl to fetch releases + asset.
		if ! (( ${+commands[curl]} )); then
			print_fn -e "curl is required"
			return 1
		fi

		local repo="${managers[$target]}"
		print_fn -i "Querying latest bootstrap release for ${target} (${repo})..."
		local release_json
		if ! release_json=$(curl -sfL -H 'Accept: application/vnd.github+json' \
			"https://api.github.com/repos/${repo}/releases?per_page=30") \
			|| [[ -z "$release_json" ]]; then
			print_fn -e "Could not fetch releases for ${repo}"
			return 1
		fi

		# Extract the first matching asset URL. Fragile-by-design grep is fine
		# here: the schema is stable and we fail loud if it changes.
		local asset_url
		asset_url=$(print -r -- "$release_json" \
			| grep -oE '"browser_download_url":[[:space:]]*"[^"]*bootstrap-'"${arch}"'\.zip"' \
			| head -1 \
			| sed -E 's/.*"(https[^"]+)".*/\1/')
		if [[ -z "$asset_url" ]]; then
			print_fn -e "No bootstrap-${arch}.zip asset found in recent releases of ${repo}"
			return 1
		fi
		print_fn -i "Asset: ${asset_url}"

		local -r dest_dir="${HOME}/storage/downloads"
		local -r dest="${dest_dir}/bootstrap-${target}-${arch}.zip"
		if [[ -f "$dest" ]]; then
			print_fn -w "${dest} already exists. Delete manually to re-download."
		else
			print_fn -i "Downloading to ${dest}..."
			if ! curl -fL --progress-bar -o "${dest}.part" "$asset_url"; then
				print_fn -e "Download failed"
				rm -f "${dest}.part"
				return 1
			fi
			mv "${dest}.part" "$dest"
		fi

		# Best-effort sha256 verification.
		local -r sha_url="${asset_url%.zip}.zip.sha256"
		local -r sha_file="${dest}.sha256"
		if curl -sfL -o "$sha_file" "$sha_url" 2>/dev/null && [[ -s "$sha_file" ]]; then
			local expected="${$(<$sha_file)%% *}"
			local actual="${$(sha256sum "$dest")%% *}"
			if [[ "$expected" == "$actual" ]]; then
				print_fn -s "sha256 OK (${actual})"
			else
				print_fn -e "sha256 mismatch: expected ${expected}, got ${actual}"
				return 1
			fi
		else
			print_fn -w "No sha256 published alongside asset; integrity not verified"
			rm -f "$sha_file"
		fi

		# Export current package list to $HOME (which survives the bootstrap
		# swap. $HOME is /data/data/com.termux/files/home, separate from usr/).
		local -r pkglist="${HOME}/termux-pkglist-${current:-unknown}-$(date +%Y%m%d-%H%M%S).txt"
		if [[ -n "$current" ]]; then
			print_fn -i "Exporting installed package list to ${pkglist}..."
			case "$current" in
			pacman) pacman -Qqe >"$pkglist" 2>/dev/null ;;
			apt)    apt list --installed 2>/dev/null \
			          | sed -nE 's|^([^/]+)/.*|\1|p' >"$pkglist" ;;
			esac
			if [[ -s "$pkglist" ]]; then
				print_fn -s "Saved $(wc -l <"$pkglist" | tr -d ' ') package names"
			else
				rm -f "$pkglist"
				print_fn -w "Could not export package list; continuing anyway"
			fi
		fi

		print_fn -s "Bootstrap staged. To complete the switch (manually):"
		cat >&2 <<-EOF

			  1. Back up first. Run:
			         termux_backup

			  2. Extract the bootstrap aside (do NOT touch usr/ yet):
			         cd /data/data/com.termux/files
			         unzip -l "${dest}" | head        # verify contents first
			         mkdir -p usr-n
			         unzip -o "${dest}" -d usr-n
			         # Re-create symlinks listed in the bootstrap manifest:
			         cd usr-n
			         awk -F '←' '{system("ln -s '"'"'"\$1"'"'"' '"'"'"\$2"'"'"'")}' SYMLINKS.txt
			         cd ..

			  3. Enter Termux failsafe mode so \$PREFIX is not in use by the
			     running shell. To launch failsafe:
			       a. Close ALL Termux sessions.
			       b. Long-press the Termux launcher icon and tap "Failsafe"
			          (recent Android), OR open Termux and long-press the
			          "New session" button in the left drawer.
			     You are now in /system/bin/sh with no \$PREFIX loaded. Swap:
			         cd /data/data/com.termux/files
			         rm -fr usr/
			         mv usr-n/ usr/

			  4. Exit failsafe, start Termux normally. If switching to pacman,
			     initialize the keyring:
			         pacman-key --init
			         pacman-key --populate

			  5. The fresh bootstrap ships only a minimal base; zsh and this
			     environment are gone (\$PREFIX/etc was wiped). From the default
			     bash/sh, install zsh first, then re-bootstrap:
			         # apt variant:    pkg install zsh
			         # pacman variant: pacman -Sy zsh
			         zsh ${ZDOTDIR:-$HOME/.local/config/zsh}/conf/first_init.zsh

			  6. Re-install packages from the exported list (names may differ
			     between repos. Review before bulk-installing):
			         ${pkglist}

			  If anything breaks, restore the backup from step 1:
			         tar -zxf <backup>.tar.gz -C /data/data/com.termux/files \\
			           --recursive-unlink --preserve-permissions

			This function deliberately does NOT perform steps 2-5.
		EOF
	}

	function termux_phantom_killer {
		local -ra usage=(
			"Usage: $0 [-v|-q] [on|off|enable|disable]"
			"Inspect or toggle Android's phantom process killer for Termux."
			""
			"  on,  enable    Re-enable the killer (Android default)"
			"  off, disable   Disable the killer so Termux background tasks survive"
			"  (no arg)       Print current state and what it means"
			""
			"  -v, --verbose  Echo each underlying command as it runs"
			"  -q, --quiet    Suppress informational output (errors still print)"
			"  -h, --help     Show this help"
			""
			"Requires shell-user (UID 2000) via rish (Shizuku); falls back to adb."
		)
		local -a o_verbose o_quiet o_help
		zparseopts -D -F -K -- \
			{v,-verbose}=o_verbose \
			{q,-quiet}=o_quiet \
			{h,-help}=o_help \
		|| { >&2 print -l $usage; return 2 }
		if (( ${#o_help} )); then >&2 print -l $usage; return 0; fi
		check_argc $# 0 1 || { >&2 print -l $usage; return 2 }

		local -ri verbose=${#o_verbose} quiet=${#o_quiet}
		if (( verbose && quiet )); then
			print_fn -e "--verbose and --quiet are mutually exclusive"
			return 2
		fi

		# Pick escalation: rish (Shizuku) preferred, adb as fallback.
		local -a runner
		if (( ${+commands[rish]} )); then
			runner=(rish -c)
		elif (( ${+commands[adb]} )); then
			runner=(adb shell)
		else
			print_fn -e "Neither rish (Shizuku) nor adb is available"
			return 1
		fi
		(( verbose )) && print_fn -d "Escalation: ${runner[1]}"

		local -r key="settings_enable_monitor_phantom_procs"
		local -r action="${1:-status}"

		case "$action" in
		status)
			local raw
			if ! raw=$("${runner[@]}" "settings get global ${key}" 2>/dev/null); then
				print_fn -e "Could not read setting via ${runner[1]}"
				return 1
			fi
			(( verbose )) && print_fn -d "raw value: ${raw}"
			raw="${raw//[$'\r\n\t ']/}"
			local state desc
			case "$raw" in
			false|0)
				state="disabled"
				desc="Termux background processes will NOT be killed by Android."
				;;
			true|1|null|"")
				state="enabled"
				desc="Android may kill Termux background processes (the default)."
				;;
			*)
				state="unknown (${raw})"
				desc="Unrecognized value; manual inspection recommended."
				;;
			esac
			if (( quiet )); then
				print -- "$state"
			else
				print_fn -i "Phantom process killer: ${state}"
				print_fn -i "${desc}"
			fi
			;;
		off|disable)
			(( verbose )) && print_fn -d "${runner[1]} :: settings put global ${key} false"
			if ! "${runner[@]}" "settings put global ${key} false"; then
				print_fn -e "Failed to disable phantom process killer"
				return 1
			fi
			(( quiet )) || print_fn -s "Phantom process killer disabled"
			;;
		on|enable)
			(( verbose )) && print_fn -d "${runner[1]} :: settings put global ${key} true"
			if ! "${runner[@]}" "settings put global ${key} true"; then
				print_fn -e "Failed to enable phantom process killer"
				return 1
			fi
			# Defensive: clear any device_config override that may also be in play.
			(( verbose )) && print_fn -d "${runner[1]} :: device_config delete activity_manager max_phantom_processes"
			"${runner[@]}" "device_config delete activity_manager max_phantom_processes" >/dev/null 2>&1
			(( quiet )) || print_fn -s "Phantom process killer enabled (Android default)"
			;;
		*)
			print_fn -e "Unknown command: ${action}"
			>&2 print -l $usage
			return 2
			;;
		esac
	}

	# Post-migration breadcrumbs left by termux_pkgmgr. Both checks are
	# self-clearing: remove the pkglist file when done, and pacman-key --init
	# creates the gnupg dir so this stops triggering.
	{
		local -a _pkglists=("${HOME}"/termux-pkglist-*.txt(NOn))
		if (( ${#_pkglists} )); then
			print_fn -i "Package list from previous migration: ${_pkglists[1]}"
			print_fn -i "Re-install with: <pkgmgr> <install options> \$(cat ${_pkglists[1]})  # review first"
		fi

		# pacman exists but its keyring dir is missing → fresh install needs
		# `pacman-key --init && --populate` once before any install will work.
		if (( ${+commands[pacman]} )) && [[ ! -d "${TERMUX__PREFIX:-}/etc/pacman.d/gnupg" ]]; then
			print_fn -w "pacman keyring not initialized; running pacman-key --init && --populate"
			pacman-key --init && pacman-key --populate
		fi
	}
fi
