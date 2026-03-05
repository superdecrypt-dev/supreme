#!/bin/bash
##----- Auto Remove Vmess
data=($(grep '^###' /etc/xray/config.json | cut -d ' ' -f 2 | sort -u))
now=$(date +"%Y-%m-%d")
for user in "${data[@]}"; do
exp=$(grep -w "^### $user" /etc/xray/config.json | cut -d ' ' -f 3 | sort -u)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(((d1 - d2) / 86400))
if [[ "$exp2" -le "0" ]]; then
sed -i "/^### $user $exp/,/^},{/d" /etc/xray/config.json
sed -i "/^### $user $exp/,/^},{/d" /etc/xray/config.json
rm -f /etc/xray/$user-tls.json /etc/xray/$user-none.json
fi
done

#----- Auto Remove Vless
data=($(grep '^#&' /etc/xray/config.json | cut -d ' ' -f 2 | sort -u))
now=$(date +"%Y-%m-%d")
for user in "${data[@]}"; do
exp=$(grep -w "^#& $user" /etc/xray/config.json | cut -d ' ' -f 3 | sort -u)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(((d1 - d2) / 86400))
if [[ "$exp2" -le "0" ]]; then
sed -i "/^#& $user $exp/,/^},{/d" /etc/xray/config.json
sed -i "/^#& $user $exp/,/^},{/d" /etc/xray/config.json
fi
done

#----- Auto Remove Trojan
data=($(grep '^#!' /etc/xray/config.json | cut -d ' ' -f 2 | sort -u))
now=$(date +"%Y-%m-%d")
for user in "${data[@]}"; do
exp=$(grep -w "^#! $user" /etc/xray/config.json | cut -d ' ' -f 3 | sort -u)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(((d1 - d2) / 86400))
if [[ "$exp2" -le "0" ]]; then
sed -i "/^#! $user $exp/,/^},{/d" /etc/xray/config.json
sed -i "/^#! $user $exp/,/^},{/d" /etc/xray/config.json
fi
done
systemctl restart xray


##------ Auto Remove SSH
cut -d: -f1,8 /etc/shadow | sed /:$/d > /tmp/expirelist.txt
totalaccounts=$(wc -l < /tmp/expirelist.txt)
for ((i=1; i<=totalaccounts; i++)); do
tuserval=$(head -n "$i" /tmp/expirelist.txt | tail -n 1)
username=$(echo "$tuserval" | cut -f1 -d:)
userexp=$(echo "$tuserval" | cut -f2 -d:)
userexpireinseconds=$((userexp * 86400))
tglexp=$(date -d @"$userexpireinseconds")
tgl=$(echo "$tglexp" | awk -F" " '{print $3}')
while [ ${#tgl} -lt 2 ]; do
tgl="0"$tgl
done
while [ ${#username} -lt 15 ]; do
username=$username" " 
done
todaystime=$(date +%s)
if [ "$userexpireinseconds" -lt "$todaystime" ]; then
userdel --force "$username"
fi
done
