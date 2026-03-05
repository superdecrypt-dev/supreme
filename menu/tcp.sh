#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

sh_ver="2.0.0"

GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
NC="\033[0m"
INFO="${GREEN}[Info]${NC}"
WARN="${YELLOW}[Warn]${NC}"
ERR="${RED}[Error]${NC}"

safe_clear() {
  clear >/dev/null 2>&1 || true
}

legacy_feature_disabled() {
  local feature="$1"
  safe_clear
  echo -e "${WARN} ${feature} is legacy and has been disabled for runtime safety."
  echo -e "${INFO} Use option 4/7/9/10 for supported tuning."
  read -r -p "Press Enter to return to menu..." _
  start_menu
}

set_sysctl_key() {
  local key="$1"
  local value="$2"

  sed -i "/^${key}[[:space:]]*=.*/d" /etc/sysctl.conf
  echo "${key} = ${value}" >> /etc/sysctl.conf
}

remove_accel_settings() {
  local keys=(
    "net.core.default_qdisc"
    "net.ipv4.tcp_congestion_control"
    "fs.file-max"
    "net.core.rmem_max"
    "net.core.wmem_max"
    "net.core.rmem_default"
    "net.core.wmem_default"
    "net.core.netdev_max_backlog"
    "net.core.somaxconn"
    "net.ipv4.tcp_syncookies"
    "net.ipv4.tcp_tw_reuse"
    "net.ipv4.tcp_tw_recycle"
    "net.ipv4.tcp_fin_timeout"
    "net.ipv4.tcp_keepalive_time"
    "net.ipv4.ip_local_port_range"
    "net.ipv4.tcp_max_syn_backlog"
    "net.ipv4.tcp_max_tw_buckets"
    "net.ipv4.tcp_rmem"
    "net.ipv4.tcp_wmem"
    "net.ipv4.tcp_mtu_probing"
    "net.ipv4.ip_forward"
    "fs.inotify.max_user_instances"
    "net.ipv4.route.gc_timeout"
    "net.ipv4.tcp_synack_retries"
    "net.ipv4.tcp_syn_retries"
    "net.ipv4.tcp_timestamps"
    "net.ipv4.tcp_max_orphans"
  )

  for key in "${keys[@]}"; do
    sed -i "/^${key}[[:space:]]*=.*/d" /etc/sysctl.conf
  done

  sysctl -p >/dev/null 2>&1 || true
  echo -e "${INFO} Acceleration tuning removed."
}

apply_tcp_accel() {
  local algo="$1"
  remove_accel_settings
  set_sysctl_key "net.core.default_qdisc" "fq"
  set_sysctl_key "net.ipv4.tcp_congestion_control" "$algo"

  if ! sysctl -p >/dev/null 2>&1; then
    echo -e "${ERR} Failed to apply sysctl settings for ${algo}."
    return 1
  fi

  local active_algo
  active_algo=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)
  if [ "$active_algo" != "$algo" ]; then
    echo -e "${WARN} ${algo} is not active on this kernel. Current: ${active_algo:-unknown}"
    return 1
  fi

  echo -e "${INFO} ${algo} acceleration is active."
  return 0
}

optimizing_system() {
  remove_accel_settings

  set_sysctl_key "fs.file-max" "1000000"
  set_sysctl_key "fs.inotify.max_user_instances" "8192"
  set_sysctl_key "net.ipv4.tcp_syncookies" "1"
  set_sysctl_key "net.ipv4.tcp_fin_timeout" "30"
  set_sysctl_key "net.ipv4.tcp_tw_reuse" "1"
  set_sysctl_key "net.ipv4.ip_local_port_range" "1024 65000"
  set_sysctl_key "net.ipv4.tcp_max_syn_backlog" "16384"
  set_sysctl_key "net.ipv4.tcp_max_tw_buckets" "6000"
  set_sysctl_key "net.ipv4.route.gc_timeout" "100"
  set_sysctl_key "net.ipv4.tcp_syn_retries" "1"
  set_sysctl_key "net.ipv4.tcp_synack_retries" "1"
  set_sysctl_key "net.core.somaxconn" "32768"
  set_sysctl_key "net.core.netdev_max_backlog" "32768"
  set_sysctl_key "net.ipv4.tcp_timestamps" "0"
  set_sysctl_key "net.ipv4.tcp_max_orphans" "32768"
  set_sysctl_key "net.ipv4.ip_forward" "1"

  if ! sysctl -p >/dev/null 2>&1; then
    echo -e "${ERR} Failed to apply optimization settings."
    return 1
  fi

  cat > /etc/security/limits.conf <<'LIMITS'
*               soft    nofile           1000000
*               hard    nofile           1000000
LIMITS

  if ! grep -qxF "ulimit -SHn 1000000" /etc/profile; then
    echo "ulimit -SHn 1000000" >> /etc/profile
  fi

  echo -e "${INFO} System optimization applied."
}

check_status() {
  local kernel
  kernel=$(uname -r)
  local algo
  algo=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")

  echo -e "Kernel : ${kernel}"
  echo -e "TCP CC : ${algo}"
}

start_menu() {
  safe_clear
  echo -e "TCP tuning manager ${GREEN}[v${sh_ver}]${NC}"
  echo
  echo -e "${YELLOW}0.${NC} Update script (disabled legacy)"
  echo -e "${YELLOW}1.${NC} Install BBR kernel (disabled legacy)"
  echo -e "${YELLOW}2.${NC} Install BBRplus kernel (disabled legacy)"
  echo -e "${YELLOW}3.${NC} Install Lotserver kernel (disabled legacy)"
  echo -e "${GREEN}4.${NC} Enable BBR acceleration"
  echo -e "${YELLOW}5.${NC} Enable BBR magic (disabled legacy)"
  echo -e "${YELLOW}6.${NC} Enable BBR nanqinlang (disabled legacy)"
  echo -e "${GREEN}7.${NC} Enable BBRplus acceleration"
  echo -e "${YELLOW}8.${NC} Enable Lotserver acceleration (disabled legacy)"
  echo -e "${GREEN}9.${NC} Remove acceleration tuning"
  echo -e "${GREEN}10.${NC} Apply system network optimization"
  echo -e "${GREEN}11.${NC} Exit"
  echo
  check_status
  echo

  read -r -p "Please enter number [0-11]: " num
  case "$num" in
    0) legacy_feature_disabled "Script self-update" ;;
    1) legacy_feature_disabled "Kernel installation (BBR)" ;;
    2) legacy_feature_disabled "Kernel installation (BBRplus)" ;;
    3) legacy_feature_disabled "Kernel installation (Lotserver)" ;;
    4)
      if apply_tcp_accel "bbr"; then
        read -r -p "Press Enter to continue..." _
      else
        read -r -p "Press Enter to continue..." _
      fi
      start_menu
      ;;
    5) legacy_feature_disabled "BBR magic acceleration" ;;
    6) legacy_feature_disabled "BBR nanqinlang acceleration" ;;
    7)
      if apply_tcp_accel "bbrplus"; then
        read -r -p "Press Enter to continue..." _
      else
        read -r -p "Press Enter to continue..." _
      fi
      start_menu
      ;;
    8) legacy_feature_disabled "Lotserver acceleration" ;;
    9)
      remove_accel_settings
      read -r -p "Press Enter to continue..." _
      start_menu
      ;;
    10)
      if optimizing_system; then
        read -r -p "Reboot recommended. Reboot now? [y/N]: " yn
        if [[ "$yn" == "y" || "$yn" == "Y" ]]; then
          reboot
        fi
      fi
      start_menu
      ;;
    11)
      exit 0
      ;;
    *)
      echo -e "${ERR} Invalid selection"
      sleep 1
      start_menu
      ;;
  esac
}

start_menu
