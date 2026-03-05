#!/bin/bash

clear

echo "----------------------------------------"
echo "---------=[ Vless User Login ]=---------"
echo "----------------------------------------"

get_active_ips() {
	if command -v ss >/dev/null 2>&1; then
		ss -tnp 2>/dev/null | awk '/ESTAB/ && /xray/ {split($5, a, ":"); print a[1]}' | sort -u
	else
		netstat -anp 2>/dev/null | awk '/ESTABLISHED/ && /tcp6/ && /xray/ {split($5, a, ":"); print a[1]}' | sort -u
	fi
}

mapfile -t users < <(grep '^####' /etc/xray/config.json 2>/dev/null | cut -d ' ' -f 2)
mapfile -t active_ips < <(get_active_ips)
declare -A matched

for akun in "${users[@]}"; do
	[ -n "$akun" ] || akun="tidakada"
	mapfile -t user_ips < <(grep -w "$akun" /var/log/xray/access.log | awk '{split($3, a, ":"); print a[1]}' | sort -u)

	user_match=()
	for ip in "${active_ips[@]}"; do
		for uip in "${user_ips[@]}"; do
			if [ "$ip" = "$uip" ]; then
				user_match+=("$ip")
				matched["$ip"]=1
				break
			fi
		done
	done

	if [ "${#user_match[@]}" -gt 0 ]; then
		echo "user : $akun"
		idx=1
		for ip in "${user_match[@]}"; do
			echo "$idx  $ip"
			idx=$((idx + 1))
		done
		echo "----------------------------------------"
	fi
done

echo "other"
idx=1
for ip in "${active_ips[@]}"; do
	if [ -z "${matched[$ip]:-}" ]; then
		echo "$idx  $ip"
		idx=$((idx + 1))
	fi
done
echo "----------------------------------------"

read -n 1 -s -r -p "Press any key to back on menu"
menu
