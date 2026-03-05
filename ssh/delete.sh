#!/bin/bash

clear
hariini=$(date +%d-%m-%Y)
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m               AUTO DELETE                \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "Thank you for removing the EXPIRED USERS"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

cut -d: -f1,8 /etc/shadow | sed '/:$/d' >/tmp/expirelist.txt

while IFS=: read -r username userexp; do
	[ -n "$username" ] || continue
	[ -n "$userexp" ] || continue

	userexpireinseconds=$((userexp * 86400))
	tglexp=$(date -d "@$userexpireinseconds")
	tgl=$(awk '{print $3}' <<<"$tglexp")
	while [ ${#tgl} -lt 2 ]; do
		tgl="0$tgl"
	done

	padded_username="$username"
	while [ ${#padded_username} -lt 15 ]; do
		padded_username="$padded_username "
	done

	bulantahun=$(awk '{print $2, $6}' <<<"$tglexp")
	printf 'echo "Expired- User : %s Expire at : %s %s"\n' "$padded_username" "$tgl" "$bulantahun" >>/usr/local/bin/alluser

	todaystime=$(date +%s)
	if [ "$userexpireinseconds" -lt "$todaystime" ]; then
		printf 'echo "Expired- Username : %s are expired at: %s %s and removed : %s "\n' "$padded_username" "$tgl" "$bulantahun" "$hariini" >>/usr/local/bin/deleteduser
		echo "Username $padded_username that are expired at $tgl $bulantahun removed from the VPS $hariini"
		userdel "$username"
	fi
done </tmp/expirelist.txt

echo " "
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

read -n 1 -s -r -p "Press any key to back on menu"
menu
