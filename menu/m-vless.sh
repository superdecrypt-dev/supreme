#!/bin/bash

clear
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;100;33m       • VLESS MENU •         \E[0m"
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
echo -e " [\e[36m•1\e[0m] Create Account Vless "
echo -e " [\e[36m•2\e[0m] Trial Account Vless "
echo -e " [\e[36m•3\e[0m] Extending Account Vless "
echo -e " [\e[36m•4\e[0m] Delete Account Vless "
echo -e " [\e[36m•5\e[0m] Check User Login Vless "
echo -e ""
echo -e " [\e[31m•0\e[0m] \e[31mBACK TO MENU\033[0m"
echo -e ""
echo -e "Press x or [ Ctrl+C ] • To-Exit"
echo ""
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
read -r -p " Select menu :  " opt
echo -e ""
case $opt in
1)
	clear
	add-vless
	;;
2)
	clear
	trialvless
	;;
3)
	clear
	renew-vless
	;;
4)
	clear
	del-vless
	;;
5)
	clear
	cek-vless
	;;
0)
	clear
	menu
	;;
x) exit ;;
*)
	echo "salah tekan "
	sleep 1
	m-vless
	;;
esac
