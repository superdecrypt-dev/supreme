#!/bin/bash

clear
number_of_clients=$(grep -c -E '^### ' /etc/xray/config.json)
if [ "$number_of_clients" = "0" ]; then
	echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
	echo -e "\\E[0;41;36m       Delete Sodosok Account      \E[0m"
	echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
	echo ""
	echo "You have no existing clients!"
	echo ""
	echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
	read -n 1 -s -r -p "Press any key to back on menu"
	menu
	exit 0
fi

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\\E[0;41;36m       Delete Sodosok Account      \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "  User       Expired"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
grep -E '^### ' /etc/xray/config.json | cut -d ' ' -f 2-3 | column -t | sort -u
echo ""
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -rp "Input Username : " user

if [ -z "$user" ]; then
	menu
	exit 0
fi

exp=$(grep -wE "^### $user" /etc/xray/config.json | cut -d ' ' -f 3 | sort -u)
if [ -z "$exp" ]; then
	echo "User not found"
	read -n 1 -s -r -p "Press any key to back on menu"
	menu
	exit 0
fi

sed -i "/^### $user $exp/,/^},{/d" /etc/xray/config.json
systemctl restart xray >/dev/null 2>&1

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo " Shadowsocks Account Deleted Successfully"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo " Client Name : $user"
echo " Expired On  : $exp"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""
read -n 1 -s -r -p "Press any key to back on menu"
menu
