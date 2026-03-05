#!/bin/bash

set -o errexit
set -o pipefail

safe_clear() {
	clear >/dev/null 2>&1 || true
}

safe_clear
green='\e[0;32m'
yell='\e[1;33m'
tyblue='\e[1;36m'
NC='\e[0m'
red() { echo -e "\\033[31;1m${*}\\033[0m"; }
SUPREME_REF_FILE="/opt/.supreme_ref"

resolve_supreme_ref() {
	if [ -n "${SUPREME_REF:-}" ]; then
		echo "$SUPREME_REF"
		return
	fi

	if [ -s "$SUPREME_REF_FILE" ]; then
		cat "$SUPREME_REF_FILE"
		return
	fi

	local script_dir
	script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	if command -v git >/dev/null 2>&1 && git -C "$script_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		git -C "$script_dir" rev-parse HEAD
		return
	fi

	# Default ref for one-line installer flow:
	# bash <(curl -fsSL https://raw.githubusercontent.com/superdecrypt-dev/supreme/main/setup.sh)
	echo "main"
}

SUPREME_REF="$(resolve_supreme_ref)"
mkdir -p /opt
echo "$SUPREME_REF" >"$SUPREME_REF_FILE"
if [[ ! "$SUPREME_REF" =~ ^[0-9a-f]{40}$ ]]; then
	echo -e "[ ${yell}WARN${NC} ] Using mutable SUPREME_REF '${SUPREME_REF}'. Prefer pinned commit hash for better supply-chain safety."
fi
RAW_BASE_URL="https://raw.githubusercontent.com/superdecrypt-dev/supreme/${SUPREME_REF}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SUPREME_LOCAL_SOURCE="${SUPREME_LOCAL_SOURCE:-$SCRIPT_DIR}"

secure_download() {
	local url="$1"
	local dest="$2"

	if [[ "$url" != https://* ]]; then
		echo -e "[ ${yell}ERROR${NC} ] Refusing non-HTTPS download: ${url}"
		return 1
	fi

	if command -v curl >/dev/null 2>&1; then
		curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
			--retry 3 --connect-timeout 15 -o "$dest" "$url"
	else
		wget --https-only --tries=3 --timeout=15 -q -O "$dest" "$url"
	fi
}

download_and_run() {
	local remote_path="$1"
	local local_name="$2"
	local url="${RAW_BASE_URL}/${remote_path}"
	local local_source="${SUPREME_LOCAL_SOURCE%/}/${remote_path}"

	if [ -f "$local_source" ]; then
		cp -f "$local_source" "$local_name"
	else
		if ! secure_download "$url" "$local_name"; then
			echo -e "[ ${yell}ERROR${NC} ] Failed to download ${url}"
			exit 1
		fi
	fi
	if [ ! -s "$local_name" ]; then
		echo -e "[ ${yell}ERROR${NC} ] Downloaded script is empty: ${local_name}"
		exit 1
	fi
	if ! head -n 1 "$local_name" | grep -q '^#!'; then
		echo -e "[ ${yell}ERROR${NC} ] Invalid script header in ${local_name}"
		exit 1
	fi
	chmod +x "$local_name"
	if ! "./$local_name"; then
		echo -e "[ ${yell}ERROR${NC} ] Failed to execute ${local_name}"
		exit 1
	fi
}

cd /root || exit 1

if [ "${EUID}" -ne 0 ]; then
	echo "You need to run this script as root"
	exit 1
fi
if [ "$(systemd-detect-virt)" = "openvz" ]; then
	echo "OpenVZ is not supported"
	exit 1
fi

check_supported_os() {
	if [ ! -r /etc/os-release ]; then
		echo -e "[ ${yell}ERROR${NC} ] Cannot detect OS (missing /etc/os-release)"
		exit 1
	fi

	# shellcheck disable=SC1091
	. /etc/os-release

	local os_id="${ID:-}"
	local os_version="${VERSION_ID:-}"

	if [ -z "$os_id" ] || [ -z "$os_version" ]; then
		echo -e "[ ${yell}ERROR${NC} ] Unable to detect OS ID/version from /etc/os-release"
		exit 1
	fi

	case "$os_id" in
	ubuntu)
		if ! dpkg --compare-versions "$os_version" ge "20.04"; then
			echo -e "[ ${yell}ERROR${NC} ] Unsupported Ubuntu version: ${os_version} (minimum: 20.04)"
			exit 1
		fi
		;;
	debian)
		if ! dpkg --compare-versions "$os_version" ge "11"; then
			echo -e "[ ${yell}ERROR${NC} ] Unsupported Debian version: ${os_version} (minimum: 11)"
			exit 1
		fi
		;;
	*)
		echo -e "[ ${yell}ERROR${NC} ] Unsupported OS: ${PRETTY_NAME:-$os_id}"
		echo -e "[ ${yell}ERROR${NC} ] Supported: Ubuntu >= 20.04 or Debian >= 11"
		exit 1
		;;
	esac

	echo -e "[ ${green}INFO${NC} ] Supported OS detected: ${PRETTY_NAME:-$os_id $os_version}"
}

install_bootstrap_packages() {
	local pkgs=(
		bzip2
		gzip
		coreutils
		screen
		curl
		unzip
		git
		wget
		python3
	)

	echo -e "[ ${green}INFO${NC} ] Installing bootstrap packages"
	apt-get update -y
	apt-get install -y "${pkgs[@]}"
}

disable_ipv6() {
	local sysctl_file="/etc/sysctl.d/99-supreme-disable-ipv6.conf"
	local failed=0

	cat >"$sysctl_file" <<'EOF'
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF

	if ! sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1; then
		echo -e "[ ${yell}WARN${NC} ] Failed to apply net.ipv6.conf.all.disable_ipv6=1"
		failed=1
	fi
	if ! sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1; then
		echo -e "[ ${yell}WARN${NC} ] Failed to apply net.ipv6.conf.default.disable_ipv6=1"
		failed=1
	fi
	if ! sysctl -p "$sysctl_file" >/dev/null 2>&1; then
		echo -e "[ ${yell}WARN${NC} ] Failed to reload ${sysctl_file}"
		failed=1
	fi

	if [ "$failed" -eq 0 ]; then
		echo -e "[ ${green}INFO${NC} ] IPv6 disabled"
	else
		echo -e "[ ${yell}WARN${NC} ] IPv6 disable may be incomplete on this host"
	fi
}

check_supported_os
install_bootstrap_packages
disable_ipv6

localip=$(hostname -I | awk '{print $1}')
hst=$(hostname)
dart=$(grep -w "$hst" /etc/hosts | awk '{print $2}' || true)
if [[ "$hst" != "$dart" ]]; then
	echo "$localip $hst" >>/etc/hosts
fi

mkdir -p /etc/xray /etc/v2ray
touch /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /etc/v2ray/scdomain

echo -e "[ ${tyblue}NOTES${NC} ] Before we go.."
sleep 0.5
echo -e "[ ${tyblue}NOTES${NC} ] I need check your headers first.."
sleep 0.5
echo -e "[ ${green}INFO${NC} ] Checking headers"
sleep 0.5

kernel_rel=$(uname -r)
required_pkg="linux-headers-$kernel_rel"
pkg_ok=$(dpkg-query -W --showformat='${Status}\n' "$required_pkg" 2>/dev/null | grep "install ok installed" || true)
echo "Checking for $required_pkg: $pkg_ok"

if [ -z "$pkg_ok" ]; then
	sleep 0.5
	echo -e "[ ${yell}WARNING${NC} ] Try to install ...."
	echo "No $required_pkg. Setting up $required_pkg."
	apt-get --yes install "$required_pkg"
	sleep 0.5
	echo ""
	sleep 0.5
	echo -e "[ ${tyblue}NOTES${NC} ] If error you need.. to do this"
	sleep 0.5
	echo ""
	sleep 0.5
	echo -e "[ ${tyblue}NOTES${NC} ] apt update && upgrade"
	sleep 0.5
	echo ""
	sleep 0.5
	echo -e "[ ${tyblue}NOTES${NC} ] After this"
	sleep 0.5
	echo -e "[ ${tyblue}NOTES${NC} ] Then run this script again"
	echo -e "[ ${tyblue}NOTES${NC} ] enter now"
	read -r
else
	echo -e "[ ${green}INFO${NC} ] Oke installed"
fi

if ! dpkg -s "$required_pkg" >/dev/null 2>&1; then
	rm -f /root/setup.sh >/dev/null 2>&1
	exit
fi

safe_clear

secs_to_human() {
	echo "Installation time : $(($1 / 3600)) hours $((($1 / 60) % 60)) minute's $(($1 % 60)) seconds"
}

install_root_menu_hook() {
	local profile="/root/.profile"
	local begin="# >>> SUPREME MENU AUTO-RUN >>>"
	local end="# <<< SUPREME MENU AUTO-RUN <<<"

	if [ ! -f "$profile" ]; then
		cat >"$profile" <<'EOF'
# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
EOF
	fi

	if grep -q '^menu$' "$profile"; then
		sed -i 's/^menu$/if [ -n "${PS1:-}" ] \&\& command -v menu >\/dev\/null 2>\&1; then menu; fi/' "$profile"
	fi

	if ! grep -qF "$begin" "$profile"; then
		cat >>"$profile" <<EOF
$begin
if [ -n "\${PS1:-}" ] && command -v menu >/dev/null 2>&1; then
  clear >/dev/null 2>&1 || true
  menu
fi
$end
EOF
	fi

	chmod 644 "$profile"
}

start=$(date +%s)
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

echo -e "[ ${green}INFO${NC} ] Preparing the install file"
echo -e "[ ${green}INFO${NC} ] Aight good ... installation file is ready"
sleep 0.5
mkdir -p /var/lib/ >/dev/null 2>&1
if ! grep -q '^IP=' /var/lib/ipvps.conf 2>/dev/null; then
	echo "IP=" >>/var/lib/ipvps.conf
fi

echo ""
safe_clear
red "Tambah Domain Untuk XRAY"
echo " "
existing_domain=""
if [ -s /root/domain ]; then
	existing_domain=$(</root/domain)
fi
read -rp "Input domain kamu : " -e dns
if [ -z "$dns" ]; then
	if [ -n "$existing_domain" ]; then
		dns="$existing_domain"
		echo -e "
        Nothing input for domain!
        Existing domain value will be kept: $dns"
	else
		echo -e "[ ${yell}ERROR${NC} ] Domain is required for XRAY installation"
		exit 1
	fi
fi

echo "$dns" >/root/scdomain
echo "$dns" >/etc/xray/scdomain
echo "$dns" >/etc/xray/domain
echo "$dns" >/etc/v2ray/domain
echo "$dns" >/root/domain
echo "IP=$dns" >/var/lib/ipvps.conf

# install ssh ovpn
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "$green      Install SSH Websocket               $NC"
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
sleep 0.5
safe_clear
download_and_run "ssh/ssh-vpn.sh" "ssh-vpn.sh"

# install xray
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "$green          Install XRAY              $NC"
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
sleep 0.5
safe_clear
download_and_run "xray/ins-xray.sh" "ins-xray.sh"
download_and_run "sshws/insshws.sh" "insshws.sh"

safe_clear
install_root_menu_hook

if [ -f /root/log-install.txt ]; then
	rm -f /root/log-install.txt >/dev/null 2>&1
fi
if [ -f /etc/afak.conf ]; then
	rm -f /etc/afak.conf >/dev/null 2>&1
fi
if [ ! -f /etc/log-create-user.log ]; then
	echo "Log All Account " >/etc/log-create-user.log
fi

history -c
echo "latest" >/opt/.ver
public_ip=$(curl -sS ifconfig.me 2>/dev/null || true)
if [ -z "$public_ip" ]; then
	public_ip=$(curl -sS ipinfo.io/ip 2>/dev/null || true)
fi
if [ -z "$public_ip" ]; then
	public_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
fi
echo "${public_ip:-N/A}" >/etc/myipvps

echo " "
echo "=====================-[ SUPREME ]-===================="
echo ""
echo "------------------------------------------------------------"
echo ""
echo "   >>> Service & Port" | tee -a log-install.txt
echo "   - OpenSSH                  : 22" | tee -a log-install.txt
echo "   - SSH Websocket            : 80 [ON]" | tee -a log-install.txt
echo "   - SSH SSL Websocket        : 443" | tee -a log-install.txt
echo "   - Stunnel4                 : 222, 777" | tee -a log-install.txt
echo "   - Dropbear                 : 109, 143" | tee -a log-install.txt
echo "   - Badvpn                   : 7100-7900" | tee -a log-install.txt
echo "   - Nginx                    : 81" | tee -a log-install.txt
echo "   - Vmess WS TLS             : 443" | tee -a log-install.txt
echo "   - Vless WS TLS             : 443" | tee -a log-install.txt
echo "   - Trojan WS TLS            : 443" | tee -a log-install.txt
echo "   - Shadowsocks WS TLS       : 443" | tee -a log-install.txt
echo "   - Vmess WS none TLS        : 80" | tee -a log-install.txt
echo "   - Vless WS none TLS        : 80" | tee -a log-install.txt
echo "   - Trojan WS none TLS       : 80" | tee -a log-install.txt
echo "   - Shadowsocks WS none TLS  : 80" | tee -a log-install.txt
echo "   - Vmess gRPC               : 443" | tee -a log-install.txt
echo "   - Vless gRPC               : 443" | tee -a log-install.txt
echo "   - Trojan gRPC              : 443" | tee -a log-install.txt
echo "   - Shadowsocks gRPC         : 443" | tee -a log-install.txt
echo ""
echo "------------------------------------------------------------"
echo ""
echo "=====================-[ SUPREME ]-===================="
echo -e ""
echo ""
echo "" | tee -a log-install.txt
rm -f /root/setup.sh /root/ins-xray.sh /root/insshws.sh >/dev/null 2>&1
secs_to_human "$(($(date +%s) - start))" | tee -a log-install.txt
echo -e "
"
echo -ne "[ ${yell}WARNING${NC} ] reboot now ? (y/n)? "
read -r answer
if [ "$answer" = "${answer#[Yy]}" ]; then
	exit 0
else
	reboot
fi
