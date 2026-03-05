#!/bin/bash

Name="Local"
Exp2="N/A"

domain=$(</etc/xray/domain 2>/dev/null)
[ -n "$domain" ] || domain="N/A"

if command -v curl >/dev/null 2>&1; then
	ISP=$(curl -s ipinfo.io/org?token=7578ac19afd785 | cut -d " " -f 2-10)
	CITY=$(curl -s ipinfo.io/city?token=7578ac19afd785)
	IPVPS=$(curl -s ipinfo.io/ip?token=7578ac19afd785)
else
	ISP="N/A"
	CITY="N/A"
	IPVPS="N/A"
fi

[ -n "$ISP" ] || ISP="N/A"
[ -n "$CITY" ] || CITY="N/A"
[ -n "$IPVPS" ] || IPVPS="N/A"

DATE2=$(date -R | cut -d " " -f -5)
os_name=$(hostnamectl 2>/dev/null | awk -F: '/Operating System/ {sub(/^[ \t]+/, "", $2); print $2; exit}')
if [ -z "$os_name" ] && [ -f /etc/os-release ]; then
	# shellcheck disable=SC1091
	source /etc/os-release
	os_name=${PRETTY_NAME:-${NAME:-Unknown}}
fi
[ -n "$os_name" ] || os_name="Unknown"

clear
echo -e "\e[33m ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "                 • SUPREME •                 "
echo -e "\e[33m ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\e[33m OS            \e[0m:  $os_name"
echo -e "\e[33m IP            \e[0m:  $IPVPS"
echo -e "\e[33m ASN           \e[0m:  $ISP"
echo -e "\e[33m CITY          \e[0m:  $CITY"
echo -e "\e[33m DOMAIN        \e[0m:  $domain"
echo -e "\e[33m DATE & TIME   \e[0m:  $DATE2"
echo -e "\e[33m ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "                 • SCRIPT MENU •                 "
echo -e "\e[33m ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e " [\e[36m•1\e[0m] SSH Menu"
echo -e " [\e[36m•2\e[0m] Vmess Menu"
echo -e " [\e[36m•3\e[0m] Vless Menu"
echo -e " [\e[36m•4\e[0m] Shadowsocks Menu"
echo -e " [\e[36m•5\e[0m] Trojan Menu"
echo -e " [\e[36m•6\e[0m] System Menu"
echo -e " [\e[36m•7\e[0m] Status Service"
echo -e " [\e[36m•8\e[0m] Clear RAM Cache"
echo -e ""
echo -e " Press x or [ Ctrl+C ] • To-Exit-Script"
echo -e ""
echo -e "\e[33m ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e " \e[33mClient Name \E[0m: $Name"
echo -e " \e[33mExpired     \E[0m: $Exp2"
echo -e "\e[33m ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
read -r -p " Select menu :  " opt
echo -e ""

case $opt in
1)
	clear
	m-sshovpn
	;;
2)
	clear
	m-vmess
	;;
3)
	clear
	m-vless
	;;
4)
	clear
	m-ssws
	;;
5)
	clear
	m-trojan
	;;
6)
	clear
	m-system
	;;
7)
	clear
	running
	;;
8)
	clear
	clearcache
	;;
x) exit ;;
*)
	echo "Anda salah tekan "
	sleep 1
	menu
	;;
esac
