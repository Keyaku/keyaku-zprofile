# TSV → aligned table renderer. Reads tab-separated rows on stdin, pads columns
# to the widest cell, and emits a left-justified table on stdout.

function print_tsv_table {
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
