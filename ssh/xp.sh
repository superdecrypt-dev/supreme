#!/bin/bash

remove_xray_expired() {
	local tag="$1"
	local user exp d1 d2 exp_days
	mapfile -t users < <(grep "^${tag}" /etc/xray/config.json | awk '{print $2}' | sort -u)
	d2=$(date +%s)

	for user in "${users[@]}"; do
		exp=$(grep -w "^${tag} ${user}" /etc/xray/config.json | awk '{print $3}' | sort -u)
		[ -n "$exp" ] || continue
		d1=$(date -d "$exp" +%s 2>/dev/null)
		[ -n "$d1" ] || continue
		exp_days=$(((d1 - d2) / 86400))
		if [ "$exp_days" -le 0 ]; then
			# Remove every matching client block for this user+exp pair.
			while grep -q "^${tag} ${user} ${exp}" /etc/xray/config.json; do
				sed -i "/^${tag} ${user} ${exp}/,/^},{/d" /etc/xray/config.json
			done
			if [ "$tag" = "###" ]; then
				rm -f "/etc/xray/${user}-tls.json" "/etc/xray/${user}-none.json"
			fi
		fi
	done
}

remove_xray_expired "###"
remove_xray_expired "#&"
remove_xray_expired "#!"
systemctl restart xray

##------ Auto Remove SSH
todaystime=$(date +%s)
while IFS=: read -r username userexp; do
	[ -n "$username" ] || continue
	[ -n "$userexp" ] || continue
	userexpireinseconds=$((userexp * 86400))
	if [ "$userexpireinseconds" -lt "$todaystime" ]; then
		userdel --force "$username"
	fi
done < <(cut -d: -f1,8 /etc/shadow | sed '/:$/d')
