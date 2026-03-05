#!/bin/bash

clear
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;100;33m          • SYSTEM MENU •          \E[0m"
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
echo -e " [\e[36m•1\e[0m] Panel Domain"
echo -e " [\e[36m•2\e[0m] Speedtest VPS"
echo -e " [\e[36m•3\e[0m] Set Auto Reboot"
echo -e " [\e[36m•4\e[0m] Restart All Service"
echo -e " [\e[36m•5\e[0m] Cek Bandwith"
echo -e " [\e[36m•6\e[0m] Install TCP BBR"
echo -e ""
echo -e " [\e[31m•0\e[0m] \e[31mBACK TO MENU\033[0m"
echo -e ""
echo -e "Press x or [ Ctrl+C ] • To-Exit"
echo -e ""
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
read -r -p " Select menu : " opt
echo -e ""
case $opt in
1)
	clear
	m-domain
	;;
2)
	clear
	speedtest
	;;
3)
	clear
	auto-reboot
	;;
4)
	clear
	restart
	;;
5)
	clear
	bw
	;;
6)
	clear
	m-tcp
	;;
0)
	clear
	menu
	;;
x) exit ;;
*)
	echo -e ""
	echo "Anda salah tekan"
	sleep 1
	m-system
	;;
esac
