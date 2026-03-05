#!/bin/bash

if grep -qow "XRAY" /root/log-install.txt; then
  domen=$(< /etc/xray/domain)
else
  domen=$(< /etc/v2ray/domain)
fi
portsshws=$(grep -w "SSH Websocket" /root/log-install.txt | cut -d: -f2 | awk '{print $1}')
wsssl=$(grep -w "SSH SSL Websocket" /root/log-install.txt | cut -d: -f2 | awk '{print $1}')

clear
IP=$(curl -sS ifconfig.me)
opensh=$(grep -w "OpenSSH" /root/log-install.txt | cut -d: -f2 | awk '{print $1}')
db=$(grep -w "Dropbear" /root/log-install.txt | cut -d: -f2 | awk '{print $1,$2}')
ssl=$(grep -w "Stunnel4" /root/log-install.txt | cut -d: -f2)
Login=trial$(</dev/urandom tr -dc X-Z0-9 | head -c4)
masaaktif=1
Pass=1
echo Ping Host
echo Create Akun: "$Login"
sleep 0.5
echo Setting Password: "$Pass"
sleep 0.5
clear
useradd -e "$(date -d "$masaaktif days" +"%Y-%m-%d")" -s /bin/false -M "$Login"
exp=$(chage -l "$Login" | awk -F": " '/Account expires/{print $2}')
echo -e "$Pass\n$Pass\n" | passwd "$Login" > /dev/null 2>&1

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m            TRIAL SSH              \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Username   : $Login"
echo -e "Password   : $Pass"
echo -e "Expired On : $exp"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "IP         : $IP"
echo -e "Host       : $domen"
echo -e "OpenSSH    : $opensh"
echo -e "Dropbear   : $db"
echo -e "SSH WS     : $portsshws"
echo -e "SSH SSL WS : $wsssl"
echo -e "SSL/TLS    : $ssl"
echo -e "UDPGW      : 7100-7900"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Payload WSS"
echo -e "GET wss://isi_bug_disini HTTP/1.1[crlf]Host: ${domen}[crlf]Upgrade: websocket[crlf][crlf]"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Payload WS"
echo -e "GET / HTTP/1.1[crlf]Host: $domen[crlf]Upgrade: websocket[crlf][crlf]"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

echo ""
read -n 1 -s -r -p "Press any key to back on menu"
menu
