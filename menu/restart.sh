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

restart_initd_or_warn() {
  local service_name=$1
  local label=$2
  restart_initd_if_present "$service_name" || echo -e "[ \033[33mWarn\033[0m ] ${label} service not installed"
}

restart_systemd_if_present() {
  local unit_name=$1
  local label=$2

  if ! command -v systemctl >/dev/null 2>&1; then
    echo -e "[ \033[33mWarn\033[0m ] systemctl not available, skip ${label}"
    return 1
  fi

  if ! systemctl list-unit-files 2>/dev/null | awk '{print $1}' | grep -qx "${unit_name}"; then
    echo -e "[ \033[33mWarn\033[0m ] ${label} service not installed"
    return 1
  fi

  if ! systemctl restart "${unit_name}" >/dev/null 2>&1; then
    echo -e "[ \033[33mWarn\033[0m ] Failed to restart ${label}"
    return 1
  fi

  return 0
}

restart_all() {
  print_begin
  restart_initd_or_warn ssh "SSH"
  restart_initd_or_warn dropbear "Dropbear"
  restart_initd_or_warn stunnel4 "Stunnel4"
  restart_initd_or_warn openvpn "OpenVPN"
  restart_initd_or_warn fail2ban "Fail2ban"
  restart_initd_or_warn cron "Cron"
  restart_initd_or_warn nginx "Nginx"
  restart_initd_or_warn squid "Squid"

  echo -e "[ \033[32mok\033[0m ] Restarting xray Service (via systemctl) "
  sleep 0.5
  restart_systemd_if_present xray.service "XRAY"

  echo -e "[ \033[32mok\033[0m ] Restarting badvpn Service (via systemctl) "
  sleep 0.5
  pkill -f "badvpn-udpgw --listen-addr 127.0.0.1:" >/dev/null 2>&1 || true
  for port in 7100 7200 7300 7400 7500 7600 7700 7800 7900; do
    screen -dmS badvpn badvpn-udpgw --listen-addr "127.0.0.1:${port}" --max-clients 500
  done

  sleep 0.5
  echo -e "[ \033[32mok\033[0m ] Restarting websocket Service (via systemctl) "
  sleep 0.5
  restart_systemd_if_present ws-dropbear.service "Websocket Dropbear"
  restart_systemd_if_present ws-stunnel.service "Websocket Stunnel"

  sleep 0.5
  echo -e "[ \033[32mok\033[0m ] Restarting Trojan Go Service (via systemctl) "
  sleep 0.5
  restart_systemd_if_present trojan-go.service "Trojan Go"
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
    2) restart_single "SSH" restart_initd_if_present ssh ;;
    3) restart_single "Dropbear" restart_initd_if_present dropbear ;;
    4) restart_single "Stunnel4" restart_initd_if_present stunnel4 ;;
    5) restart_single "Openvpn" restart_initd_if_present openvpn ;;
    6) restart_single "Squid" restart_initd_if_present squid ;;
    7) restart_single "Nginx" restart_initd_if_present nginx ;;
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
    9) restart_single "XRAY" restart_systemd_if_present xray.service "XRAY" ;;
    10)
      print_begin
      echo -e "[ \033[32mok\033[0m ] Restarting websocket Service (via systemctl) "
      sleep 0.5
      ws_ok=0
      restart_systemd_if_present ws-dropbear.service "Websocket Dropbear" && ws_ok=1
      restart_systemd_if_present ws-stunnel.service "Websocket Stunnel" && ws_ok=1
      sleep 0.5
      if [ "$ws_ok" -eq 1 ]; then
        echo -e "[ \033[32mInfo\033[0m ] WEBSOCKET Service Restarted"
      else
        echo -e "[ \033[33mWarn\033[0m ] WEBSOCKET services not installed or failed"
      fi
      pause_back
      ;;
    11) restart_single "Trojan Go" restart_systemd_if_present trojan-go.service "Trojan Go" ;;
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
