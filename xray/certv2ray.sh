#!/bin/bash

red='\e[1;31m'
green='\e[0;32m'
NC='\e[0m'

clear
echo -e "[ ${green}INFO${NC} ] Start"
sleep 0.5
systemctl stop nginx

domain=$(cut -d'=' -f2 /var/lib/ipvps.conf)
port80_proc=$(lsof -i:80 -sTCP:LISTEN -nP 2>/dev/null | awk 'NR==2 {print $1}')

if [ -n "$port80_proc" ]; then
  sleep 1
  echo -e "[ ${red}WARNING${NC} ] Detected port 80 used by $port80_proc"
  systemctl stop "$port80_proc"
  sleep 2
  echo -e "[ ${green}INFO${NC} ] Processing to stop $port80_proc"
  sleep 1
fi

echo -e "[ ${green}INFO${NC} ] Starting renew cert..."
sleep 2
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d "$domain" --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
echo -e "[ ${green}INFO${NC} ] Renew cert done..."
sleep 2
printf '%s\n' "$domain" > /etc/xray/domain

if [ -n "$port80_proc" ]; then
  echo -e "[ ${green}INFO${NC} ] Starting service $port80_proc"
  sleep 2
  systemctl restart "$port80_proc"
fi

systemctl restart nginx
echo -e "[ ${green}INFO${NC} ] All finished..."
sleep 0.5
echo ""
read -n 1 -s -r -p "Press any key to back on menu"
menu
