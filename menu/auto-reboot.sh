#!/bin/bash

clear
if [ ! -e /usr/local/bin/reboot_otomatis ]; then
	cat >/usr/local/bin/reboot_otomatis <<'SCRIPT'
#!/bin/bash
tanggal=$(date +"%m-%d-%Y")
waktu=$(date +"%T")
echo "Server successfully rebooted on the date of $tanggal hit $waktu." >> /root/log-reboot.txt
/sbin/shutdown -r now
SCRIPT
	chmod +x /usr/local/bin/reboot_otomatis
fi

clear
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\e[0;100;33m       • AUTO-REBOOT MENU •        \e[0m"
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
echo -e "[\e[36m•1\e[0m] Set Auto-Reboot Setiap 1 Jam"
echo -e "[\e[36m•2\e[0m] Set Auto-Reboot Setiap 6 Jam"
echo -e "[\e[36m•3\e[0m] Set Auto-Reboot Setiap 12 Jam"
echo -e "[\e[36m•4\e[0m] Set Auto-Reboot Setiap 1 Hari"
echo -e "[\e[36m•5\e[0m] Set Auto-Reboot Setiap 1 Minggu"
echo -e "[\e[36m•6\e[0m] Set Auto-Reboot Setiap 1 Bulan"
echo -e "[\e[36m•7\e[0m] Matikan Auto-Reboot"
echo -e "[\e[36m•8\e[0m] View reboot log"
echo -e "[\e[36m•9\e[0m] Remove reboot log"
echo -e ""
echo -e " [\e[31m•0\e[0m] \e[31mBACK TO MENU\033[0m"
echo -e ""
echo -e "Press x or [ Ctrl+C ] • To-Exit"
echo -e ""
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
read -r -p " Select menu : " x

case "$x" in
1)
	echo "10 * * * * root /usr/local/bin/reboot_otomatis" >/etc/cron.d/reboot_otomatis
	echo "Auto-Reboot has been set every an hour."
	;;
2)
	echo "10 */6 * * * root /usr/local/bin/reboot_otomatis" >/etc/cron.d/reboot_otomatis
	echo "Auto-Reboot has been successfully set every 6 hours."
	;;
3)
	echo "10 */12 * * * root /usr/local/bin/reboot_otomatis" >/etc/cron.d/reboot_otomatis
	echo "Auto-Reboot has been successfully set every 12 hours."
	;;
4)
	echo "10 0 * * * root /usr/local/bin/reboot_otomatis" >/etc/cron.d/reboot_otomatis
	echo "Auto-Reboot has been successfully set once a day."
	;;
5)
	echo "10 0 */7 * * root /usr/local/bin/reboot_otomatis" >/etc/cron.d/reboot_otomatis
	echo "Auto-Reboot has been successfully set once a week."
	;;
6)
	echo "10 0 1 * * root /usr/local/bin/reboot_otomatis" >/etc/cron.d/reboot_otomatis
	echo "Auto-Reboot has been successfully set once a month."
	;;
7)
	rm -f /etc/cron.d/reboot_otomatis
	echo "Auto-Reboot successfully TURNED OFF."
	;;
8)
	if [ ! -e /root/log-reboot.txt ]; then
		clear
		echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
		echo -e "\e[0;100;33m        • AUTO-REBOOT LOG •        \e[0m"
		echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
		echo -e ""
		echo "No reboot activity found"
		echo -e ""
		echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
		echo ""
		read -n 1 -s -r -p "Press any key to back on menu"
		auto-reboot
	else
		clear
		echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
		echo -e "\e[0;100;33m        • AUTO-REBOOT LOG •        \e[0m"
		echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
		echo -e ""
		echo "LOG REBOOT"
		cat /root/log-reboot.txt
		echo -e ""
		echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
		echo ""
		read -n 1 -s -r -p "Press any key to back on menu"
		auto-reboot
	fi
	;;
9)
	clear
	echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
	echo -e "\e[0;100;33m        • AUTO-REBOOT LOG •        \e[0m"
	echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
	echo -e ""
	echo "" >/root/log-reboot.txt
	echo "Auto Reboot Log successfully deleted!"
	echo -e ""
	echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
	echo ""
	read -n 1 -s -r -p "Press any key to back on menu"
	auto-reboot
	;;
0)
	clear
	m-system
	;;
*)
	clear
	echo ""
	echo "Options Not Found In Menu"
	echo ""
	read -n 1 -s -r -p "Press any key to back on menu"
	auto-reboot
	;;
esac
