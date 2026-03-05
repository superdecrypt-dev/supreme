#!/bin/bash

clear
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;100;33m       • SSH MENU •         \E[0m"
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
echo -e " [\e[36m•1\e[0m] Create SSH & OpenVPN Account "
echo -e " [\e[36m•2\e[0m] Trial Account SSH & OpenVPN "
echo -e " [\e[36m•3\e[0m] Renew SSH & OpenVPN Account "
echo -e " [\e[36m•4\e[0m] Delete SSH & OpenVPN Account "
echo -e " [\e[36m•5\e[0m] Check User Login SSH & OpenVPN "
echo -e " [\e[36m•6\e[0m] List Member SSH & OpenVPN "
echo -e " [\e[36m•7\e[0m] Delete User Expired SSH & OpenVPN "
echo -e " [\e[36m•8\e[0m] Set up Autokill SSH "
echo -e " [\e[36m•9\e[0m] Cek Users Who Do Multi Login Multi"
echo -e ""
echo -e " [\e[31m•0\e[0m] \e[31mBACK TO MENU\033[0m"
echo -e ""
echo -e   "Press x or [ Ctrl+C ] • To-Exit"
echo ""
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
read -p " Select menu :  "  opt
echo -e ""
case $opt in
1) clear ; usernew ;;
2) clear ; trial ;;
3) clear ; renew ;;
4) clear ; hapus ;;
5) clear ; cek ;;
6) clear ; member ;;
7) clear ; delete ;;
8) clear ; autokill ;;
9) clear ; ceklim ;;
0) clear ; menu ;;
x) exit ;;
*) echo "Anda salah tekan " ; sleep 1 ; m-sshovpn ;;
esac
