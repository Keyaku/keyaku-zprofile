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
		if (( ${#o_help} )) || ! check_argc $# -eq 0; then
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
				print_fn -e "${HOME}/storage missing — run 'termux-setup-storage' first"
				return 1
			elif [[ ! -L "${HOME}/storage/downloads" ]]; then
				print_fn -e "${HOME}/storage/downloads is not a symlink — storage permission likely not granted"
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
		# the backup is self-contained — no dependency on this zsh setup.
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
fi
