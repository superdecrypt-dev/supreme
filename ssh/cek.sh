#!/bin/bash

clear
echo " "

LOG=""
if [ -e /var/log/auth.log ]; then
	LOG=/var/log/auth.log
fi
if [ -e /var/log/secure ]; then
	LOG=/var/log/secure
fi

print_dropbear() {
	echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
	echo -e "\E[0;41;36m         Dropbear User Login       \E[0m"
	echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
	echo "ID  |  Username  |  IP Address"
	echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

	if [ -z "$LOG" ]; then
		echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
		return
	fi

	mapfile -t pids < <(ps aux | awk '/[d]ropbear/ {print $2}')
	for pid in "${pids[@]}"; do
		mapfile -t lines < <(grep -i "dropbear\[$pid\]" "$LOG" | grep -i 'Password auth succeeded')
		if [ "${#lines[@]}" -eq 1 ]; then
			user=$(awk '{print $10}' <<<"${lines[0]}")
			ip=$(awk '{print $12}' <<<"${lines[0]}")
			echo "$pid - $user - $ip"
		fi
		echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
	done
}

print_ssh() {
	echo " "
	echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
	echo -e "\E[0;41;36m          OpenSSH User Login       \E[0m"
	echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
	echo "ID  |  Username  |  IP Address"
	echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

	if [ -z "$LOG" ]; then
		echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
		return
	fi

	mapfile -t pids < <(ps aux | awk '/\[priv\]/ {print $2}')
	for pid in "${pids[@]}"; do
		mapfile -t lines < <(grep -i "sshd\[$pid\]" "$LOG" | grep -i 'Accepted password for')
		if [ "${#lines[@]}" -eq 1 ]; then
			user=$(awk '{print $9}' <<<"${lines[0]}")
			ip=$(awk '{print $11}' <<<"${lines[0]}")
			echo "$pid - $user - $ip"
		fi
		echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
	done
}

print_openvpn() {
	if [ -f /etc/openvpn/server/openvpn-tcp.log ]; then
		echo " "
		echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
		echo -e "\E[0;41;36m          OpenVPN TCP User Login         \E[0m"
		echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
		echo "Username  |  IP Address  |  Connected Since"
		echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
		grep -w '^CLIENT_LIST' /etc/openvpn/server/openvpn-tcp.log | cut -d ',' -f 2,3,8 | sed 's/,/      /g'
	fi
	echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

	if [ -f /etc/openvpn/server/openvpn-udp.log ]; then
		echo " "
		echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
		echo -e "\E[0;41;36m          OpenVPN UDP User Login         \E[0m"
		echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
		echo "Username  |  IP Address  |  Connected Since"
		echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
		grep -w '^CLIENT_LIST' /etc/openvpn/server/openvpn-udp.log | cut -d ',' -f 2,3,8 | sed 's/,/      /g'
	fi
	echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
	echo ""
}

print_dropbear
print_ssh
print_openvpn

read -n 1 -s -r -p "Press any key to back on menu"
menu
