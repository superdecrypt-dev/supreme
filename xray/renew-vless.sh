#!/bin/bash

clear
number_of_clients=$(grep -c -E '^#& ' /etc/xray/config.json)
if [ "$number_of_clients" = "0" ]; then
	echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
	echo -e "\E[44;1;39m          ⇱ Renew Vless ⇲          \E[0m"
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
echo -e "\E[44;1;39m          ⇱ Renew Vless ⇲          \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""
grep -E '^#& ' /etc/xray/config.json | cut -d ' ' -f 2-3 | column -t | sort -u
echo ""
echo "tap enter to go back"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -rp "Input Username : " user

if [ -z "$user" ]; then
	menu
	exit 0
fi

read -rp "Expired (days): " masaaktif
exp=$(grep -wE "^#& $user" /etc/xray/config.json | cut -d ' ' -f 3 | sort -u)
if [ -z "$exp" ]; then
	echo "User not found"
	read -n 1 -s -r -p "Press any key to back on menu"
	menu
	exit 0
fi

now=$(date +%Y-%m-%d)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(((d1 - d2) / 86400))
exp3=$((exp2 + masaaktif))
exp4=$(date -d "$exp3 days" +"%Y-%m-%d")

sed -i "/#& $user/c\#& $user $exp4" /etc/xray/config.json
systemctl restart xray >/dev/null 2>&1

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo " VLESS Account Was Successfully Renewed"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""
echo " Client Name : $user"
echo " Expired On  : $exp4"
echo ""
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""
read -n 1 -s -r -p "Press any key to back on menu"
menu
