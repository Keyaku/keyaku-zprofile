(( ${#commands[(I)fail2ban-*]} || ${#aliases[(I)fail2ban-*]} )) || return

function fail2ban-banned-ips {
	python3 -c "
import sqlite3
conn = sqlite3.connect('fail2ban.sqlite3')
for row in conn.execute('SELECT jail, ip, timeofban, bantime FROM bans ORDER BY timeofban DESC;'):
	print(row)
"
}
