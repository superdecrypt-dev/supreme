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
  echo -e " [\e[36m•5\e[0m] Restart OpenVPN (if installed)"
  echo -e " [\e[36m•6\e[0m] Restart Squid (if installed)"
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

restart_initd_if_present() {
  local service_name=$1
  if [ ! -x "/etc/init.d/$service_name" ]; then
    return 1
  fi
  /etc/init.d/"$service_name" restart
}

restart_all() {
  print_begin
  /etc/init.d/ssh restart
  /etc/init.d/dropbear restart
  /etc/init.d/stunnel4 restart
  restart_initd_if_present openvpn || echo -e "[ \033[33mWarn\033[0m ] OpenVPN service not installed"
  /etc/init.d/fail2ban restart
  /etc/init.d/cron restart
  /etc/init.d/nginx restart
  if [ -x /etc/init.d/squid ]; then
    /etc/init.d/squid restart
  fi

  echo -e "[ \033[32mok\033[0m ] Restarting xray Service (via systemctl) "
  sleep 0.5
  systemctl restart xray

  echo -e "[ \033[32mok\033[0m ] Restarting badvpn Service (via systemctl) "
  sleep 0.5
  pkill -f "badvpn-udpgw --listen-addr 127.0.0.1:" >/dev/null 2>&1 || true
  for port in 7100 7200 7300 7400 7500 7600 7700 7800 7900; do
    screen -dmS badvpn badvpn-udpgw --listen-addr "127.0.0.1:${port}" --max-clients 500
  done

  sleep 0.5
  echo -e "[ \033[32mok\033[0m ] Restarting websocket Service (via systemctl) "
  sleep 0.5
  systemctl restart ws-dropbear.service
  systemctl restart ws-stunnel.service

  sleep 0.5
  echo -e "[ \033[32mok\033[0m ] Restarting Trojan Go Service (via systemctl) "
  sleep 0.5
  if systemctl list-unit-files | awk '{print $1}' | grep -qx 'trojan-go.service'; then
    systemctl restart trojan-go.service
  else
    echo -e "[ \033[33mWarn\033[0m ] Trojan Go service not installed"
  fi
  sleep 0.5

  echo -e "[ \033[32mInfo\033[0m ] ALL Service Restarted"
  pause_back
}

restart_single() {
  local svc_name=$1
  shift
  print_begin
  if "$@"; then
    echo -e "[ \033[32mInfo\033[0m ] ${svc_name} Service Restarted"
  else
    echo -e "[ \033[33mWarn\033[0m ] ${svc_name} Service not available or failed to restart"
  fi
  sleep 0.5
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
    5) restart_single "Openvpn" restart_initd_if_present openvpn ;;
    6) restart_single "Squid" restart_initd_if_present squid ;;
    7) restart_single "Nginx" /etc/init.d/nginx restart ;;
    8)
      print_begin
      echo -e "[ \033[32mok\033[0m ] Restarting badvpn Service (via systemctl) "
      pkill -f "badvpn-udpgw --listen-addr 127.0.0.1:" >/dev/null 2>&1 || true
      for port in 7100 7200 7300 7400 7500 7600 7700 7800 7900; do
        screen -dmS badvpn badvpn-udpgw --listen-addr "127.0.0.1:${port}" --max-clients 500
      done
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
      if systemctl list-unit-files | awk '{print $1}' | grep -qx 'trojan-go.service'; then
        systemctl restart trojan-go.service
        echo -e "[ \033[32mInfo\033[0m ] Trojan Go Service Restarted"
      else
        echo -e "[ \033[33mWarn\033[0m ] Trojan Go service not installed"
      fi
      sleep 0.5
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
