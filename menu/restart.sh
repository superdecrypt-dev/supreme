#!/bin/bash

print_menu() {
  clear
  echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  echo -e "\E[0;100;33m         • RESTART MENU •          \E[0m"
  echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  echo -e ""
  echo -e " [\e[36m•1\e[0m] Restart All Services"
  echo -e " [\e[36m•2\e[0m] Restart OpenSSH"
  echo -e " [\e[36m•3\e[0m] Restart Dropbear"
  echo -e " [\e[36m•4\e[0m] Restart Stunnel4"
  echo -e " [\e[36m•5\e[0m] Restart OpenVPN"
  echo -e " [\e[36m•6\e[0m] Restart Squid"
  echo -e " [\e[36m•7\e[0m] Restart Nginx"
  echo -e " [\e[36m•8\e[0m] Restart Badvpn"
  echo -e " [\e[36m•9\e[0m] Restart XRAY"
  echo -e " [\e[36m10\e[0m] Restart WEBSOCKET"
  echo -e " [\e[36m11\e[0m] Restart Trojan Go"
  echo -e ""
  echo -e " [\e[31m•0\e[0m] \e[31mBACK TO MENU\033[0m"
  echo -e ""
  echo -e "Press x or [ Ctrl+C ] • To-Exit"
  echo -e ""
  echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  echo -e ""
}

print_begin() {
  clear
  echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  echo -e "\E[0;100;33m         • RESTART MENU •          \E[0m"
  echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  echo -e ""
  echo -e "[ \033[32mInfo\033[0m ] Restart Begin"
  sleep 1
}

pause_back() {
  echo ""
  echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  echo ""
  read -n 1 -s -r -p "Press any key to back on system menu"
}

restart_all() {
  print_begin
  /etc/init.d/ssh restart
  /etc/init.d/dropbear restart
  /etc/init.d/stunnel4 restart
  /etc/init.d/openvpn restart
  /etc/init.d/fail2ban restart
  /etc/init.d/cron restart
  /etc/init.d/nginx restart
  /etc/init.d/squid restart

  echo -e "[ \033[32mok\033[0m ] Restarting xray Service (via systemctl) "
  sleep 0.5
  systemctl restart xray

  echo -e "[ \033[32mok\033[0m ] Restarting badvpn Service (via systemctl) "
  sleep 0.5
  screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500

  sleep 0.5
  echo -e "[ \033[32mok\033[0m ] Restarting websocket Service (via systemctl) "
  sleep 0.5
  systemctl restart ws-dropbear.service
  systemctl restart ws-stunnel.service

  sleep 0.5
  echo -e "[ \033[32mok\033[0m ] Restarting Trojan Go Service (via systemctl) "
  sleep 0.5
  systemctl restart trojan-go.service
  sleep 0.5

  echo -e "[ \033[32mInfo\033[0m ] ALL Service Restarted"
  pause_back
}

restart_single() {
  local svc_name=$1
  shift
  print_begin
  "$@"
  sleep 0.5
  echo -e "[ \033[32mInfo\033[0m ] ${svc_name} Service Restarted"
  pause_back
}

while true; do
  print_menu
  read -r -p " Select menu : " Restart
  echo -e ""
  sleep 1

  case "$Restart" in
    1) restart_all ;;
    2) restart_single "SSH" /etc/init.d/ssh restart ;;
    3) restart_single "Dropbear" /etc/init.d/dropbear restart ;;
    4) restart_single "Stunnel4" /etc/init.d/stunnel4 restart ;;
    5) restart_single "Openvpn" /etc/init.d/openvpn restart ;;
    6) restart_single "Squid" /etc/init.d/squid restart ;;
    7) restart_single "Nginx" /etc/init.d/nginx restart ;;
    8)
      print_begin
      echo -e "[ \033[32mok\033[0m ] Restarting badvpn Service (via systemctl) "
      screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500
      sleep 0.5
      echo -e "[ \033[32mInfo\033[0m ] Badvpn Service Restarted"
      pause_back
      ;;
    9)
      print_begin
      echo -e "[ \033[32mok\033[0m ] Restarting xray Service (via systemctl) "
      systemctl restart xray
      sleep 0.5
      echo -e "[ \033[32mInfo\033[0m ] XRAY Service Restarted"
      pause_back
      ;;
    10)
      print_begin
      echo -e "[ \033[32mok\033[0m ] Restarting websocket Service (via systemctl) "
      sleep 0.5
      systemctl restart ws-dropbear.service
      systemctl restart ws-stunnel.service
      sleep 0.5
      echo -e "[ \033[32mInfo\033[0m ] WEBSOCKET Service Restarted"
      pause_back
      ;;
    11)
      print_begin
      echo -e "[ \033[32mok\033[0m ] Restarting Trojan Go Service (via systemctl) "
      sleep 0.5
      systemctl restart trojan-go.service
      sleep 0.5
      echo -e "[ \033[32mInfo\033[0m ] Trojan Go Service Restarted"
      pause_back
      ;;
    0)
      menu
      exit 0
      ;;
    x)
      clear
      exit 0
      ;;
    *)
      echo -e ""
      echo "Boh salah tekan, Sayang kedak Babi"
      sleep 1
      ;;
  esac
done
