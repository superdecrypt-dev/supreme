#!/bin/bash
# SCRIPT ENVY VPN

clear
max_allowed=1
os_type=0
log_file=""

if [ -e /var/log/auth.log ]; then
	os_type=1
	log_file=/var/log/auth.log
fi
if [ -e /var/log/secure ]; then
	os_type=2
	log_file=/var/log/secure
fi

if [ "$os_type" -eq 0 ]; then
	echo "No auth log found."
	exit 0
fi

if [ "$os_type" -eq 1 ]; then
	service ssh restart >/dev/null 2>&1
fi
if [ "$os_type" -eq 2 ]; then
	service sshd restart >/dev/null 2>&1
fi
service dropbear restart >/dev/null 2>&1

if [ -n "${1:-}" ]; then
	max_allowed=$1
fi

mapfile -t usernames < <(awk -F: '/\/home\// {print $1}' /etc/passwd)
for i in "${!usernames[@]}"; do
	counts[i]=0
	pids[i]=""
done

mapfile -t dropbear_pids < <(ps aux | awk '/[d]ropbear/ {print $2}')
for pid in "${dropbear_pids[@]}"; do
	mapfile -t lines < <(grep -i "dropbear\[$pid\]" "$log_file" | grep -i 'Password auth succeeded')
	if [ "${#lines[@]}" -eq 1 ]; then
		user=$(awk '{print $10}' <<<"${lines[0]}" | tr -d "'")
		for i in "${!usernames[@]}"; do
			if [ "$user" = "${usernames[$i]}" ]; then
				counts[i]=$((counts[i] + 1))
				pids[i]="${pids[i]} $pid"
			fi
		done
	fi
done

mapfile -t ssh_pids < <(ps aux | awk '/\[priv\]/ {print $2}')
for pid in "${ssh_pids[@]}"; do
	mapfile -t lines < <(grep -i "sshd\[$pid\]" "$log_file" | grep -i 'Accepted password for')
	if [ "${#lines[@]}" -eq 1 ]; then
		user=$(awk '{print $9}' <<<"${lines[0]}")
		for i in "${!usernames[@]}"; do
			if [ "$user" = "${usernames[$i]}" ]; then
				counts[i]=$((counts[i] + 1))
				pids[i]="${pids[i]} $pid"
			fi
		done
	fi
done

killed=0
for i in "${!usernames[@]}"; do
	if [ "${counts[$i]}" -gt "$max_allowed" ]; then
		now=$(date +"%Y-%m-%d %X")
		echo "$now - ${usernames[$i]} - ${counts[$i]}"
		echo "$now - ${usernames[$i]} - ${counts[$i]}" >>/root/log-limit.txt
		if [ -n "${pids[$i]}" ]; then
			# shellcheck disable=SC2086
			kill ${pids[$i]} 2>/dev/null
		fi
		pids[i]=""
		killed=$((killed + 1))
	fi
done

if [ "$killed" -gt 0 ]; then
	if [ "$os_type" -eq 1 ]; then
		service ssh restart >/dev/null 2>&1
	fi
	if [ "$os_type" -eq 2 ]; then
		service sshd restart >/dev/null 2>&1
	fi
	service dropbear restart >/dev/null 2>&1
fi
