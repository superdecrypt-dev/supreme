#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

# GETTING OS INFORMATION
if [ -f /etc/os-release ]; then
	# shellcheck disable=SC1091
	source /etc/os-release
fi
Tipe=${NAME:-Unknown}

# VPS ISP INFORMATION
MYIP=$(curl -sS ifconfig.me 2>/dev/null)
if [ -z "$MYIP" ]; then
	MYIP=$(curl -sS ipinfo.io/ip 2>/dev/null)
fi
if [ -z "$MYIP" ]; then
	MYIP=$(hostname -I 2>/dev/null | awk '{print $1}')
fi
if [ -z "$MYIP" ]; then
	MYIP="N/A"
fi

systemd_state() {
	local unit=$1
	local state

	if ! command -v systemctl >/dev/null 2>&1; then
		echo "missing"
		return
	fi

	state=$(systemctl is-active "$unit" 2>/dev/null || true)
	if [ "$state" = "active" ]; then
		echo "running"
	elif [ -z "$state" ] || [ "$state" = "unknown" ] || [ "$state" = "not-found" ]; then
		echo "missing"
	else
		echo "stopped"
	fi
}

initd_state() {
	local service=$1

	if [ ! -x "/etc/init.d/$service" ]; then
		echo "missing"
		return
	fi

	if "/etc/init.d/$service" status >/dev/null 2>&1; then
		echo "running"
	else
		echo "stopped"
	fi
}

format_status() {
	local state=$1

	if [ "$state" = "running" ]; then
		echo " ${GREEN}Running ${NC}( No Error )"
	elif [ "$state" = "missing" ]; then
		echo "${ORANGE}  Not Installed ${NC}( Skipped )"
	else
		echo "${RED}  Not Running ${NC}  ( Error )"
	fi
}

# CHECK STATUS
xray_state=$(systemd_state xray.service)

dropbear_status=$(initd_state dropbear)
stunnel_service=$(initd_state stunnel4)
ssh_service=$(initd_state ssh)
vnstat_service=$(initd_state vnstat)
cron_service=$(initd_state cron)
fail2ban_service=$(initd_state fail2ban)

wstls=$(systemd_state ws-stunnel.service)
wsdrop=$(systemd_state ws-dropbear.service)

status_ssh=$(format_status "$ssh_service")
status_vnstat=$(format_status "$vnstat_service")
status_cron=$(format_status "$cron_service")
status_fail2ban=$(format_status "$fail2ban_service")
status_tls_v2ray=$(format_status "$xray_state")
status_nontls_v2ray=$(format_status "$xray_state")
status_tls_vless=$(format_status "$xray_state")
status_nontls_vless=$(format_status "$xray_state")
status_virus_trojan=$(format_status "$xray_state")
status_beruangjatuh=$(format_status "$dropbear_status")
status_stunnel=$(format_status "$stunnel_service")
swstls=$(format_status "$wstls")
swsdrop=$(format_status "$wsdrop")
status_shadowsocks=$(format_status "$xray_state")

# TOTAL RAM
total_ram=$(grep "MemTotal: " /proc/meminfo | awk '{ print $2}')
totalram=$((total_ram / 1024))

Name="Local"
Exp="N/A"
if [ -s /etc/xray/domain ]; then
	Domen=$(</etc/xray/domain)
else
	Domen="N/A"
fi
echo -e ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "\E[44;1;39m              ⇱ SYSTEM INFORMATION ⇲      \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "❇️ Hostname    : $HOSTNAME"
echo -e "❇️ OS Name     : $Tipe"
echo -e "❇️ Total RAM   : ${totalram}MB"
echo -e "❇️ Public IP   : $MYIP"
echo -e "❇️ Domain      : $Domen"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "\E[44;1;39m          ⇱ SUBSCRIPTION INFORMATION ⇲          \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "❇️ Client Name : $Name"
echo -e "❇️ Exp Script  : $Exp"
echo -e "❇️ Version     : Latest Version"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "\E[44;1;39m            ⇱ SERVICE INFORMATION ⇲             \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "❇️ SSH / TUN               :$status_ssh"
echo -e "❇️ Dropbear                :$status_beruangjatuh"
echo -e "❇️ Stunnel4                :$status_stunnel"
echo -e "❇️ Fail2Ban                :$status_fail2ban"
echo -e "❇️ Crons                   :$status_cron"
echo -e "❇️ Vnstat                  :$status_vnstat"
echo -e "❇️ XRAYS Vmess TLS         :$status_tls_v2ray"
echo -e "❇️ XRAYS Vmess None TLS    :$status_nontls_v2ray"
echo -e "❇️ XRAYS Vless TLS         :$status_tls_vless"
echo -e "❇️ XRAYS Vless None TLS    :$status_nontls_vless"
echo -e "❇️ XRAYS Trojan            :$status_virus_trojan"
echo -e "❇️ Shadowsocks             :$status_shadowsocks"
echo -e "❇️ Websocket TLS           :$swstls"
echo -e "❇️ Websocket None TLS      :$swsdrop"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo ""
