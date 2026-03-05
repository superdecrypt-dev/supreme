#!/bin/bash

clear
green='\e[0;32m'
yell='\e[1;33m'
tyblue='\e[1;36m'
NC='\e[0m'
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

cd /root || exit 1

if [ "${EUID}" -ne 0 ]; then
  echo "You need to run this script as root"
  exit 1
fi
if [ "$(systemd-detect-virt)" = "openvz" ]; then
  echo "OpenVZ is not supported"
  exit 1
fi

localip=$(hostname -I | awk '{print $1}')
hst=$(hostname)
dart=$(grep -w "$hst" /etc/hosts | awk '{print $2}')
if [[ "$hst" != "$dart" ]]; then
  echo "$localip $hst" >> /etc/hosts
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
pkg_ok=$(dpkg-query -W --showformat='${Status}\n' "$required_pkg" 2>/dev/null | grep "install ok installed")
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

clear

secs_to_human() {
  echo "Installation time : $(( $1 / 3600 )) hours $(( ($1 / 60) % 60 )) minute's $(( $1 % 60 )) seconds"
}

start=$(date +%s)
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1

echo -e "[ ${green}INFO${NC} ] Preparing the install file"
apt install git curl -y >/dev/null 2>&1
apt install python -y >/dev/null 2>&1
echo -e "[ ${green}INFO${NC} ] Aight good ... installation file is ready"
sleep 0.5
mkdir -p /var/lib/ >/dev/null 2>&1
if ! grep -q '^IP=' /var/lib/ipvps.conf 2>/dev/null; then
  echo "IP=" >> /var/lib/ipvps.conf
fi

echo ""
clear
red "Tambah Domain Untuk XRAY"
echo " "
read -rp "Input domain kamu : " -e dns
if [ -z "$dns" ]; then
  echo -e "
        Nothing input for domain!
        Existing domain value will be kept"
else
  echo "$dns" > /root/scdomain
  echo "$dns" > /etc/xray/scdomain
  echo "$dns" > /etc/xray/domain
  echo "$dns" > /etc/v2ray/domain
  echo "$dns" > /root/domain
  echo "IP=$dns" > /var/lib/ipvps.conf
fi

# install ssh ovpn
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "$green      Install SSH Websocket               $NC"
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
sleep 0.5
clear
wget https://raw.githubusercontent.com/nanotechid/supreme/aio/ssh/ssh-vpn.sh && chmod +x ssh-vpn.sh && ./ssh-vpn.sh

# install xray
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "$green          Install XRAY              $NC"
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
sleep 0.5
clear
wget https://raw.githubusercontent.com/nanotechid/supreme/aio/xray/ins-xray.sh && chmod +x ins-xray.sh && ./ins-xray.sh
wget https://raw.githubusercontent.com/nanotechid/supreme/aio/sshws/insshws.sh && chmod +x insshws.sh && ./insshws.sh

clear
cat > /root/.profile << END
# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
clear
menu
END
chmod 644 /root/.profile

if [ -f /root/log-install.txt ]; then
  rm /root/log-install.txt > /dev/null 2>&1
fi
if [ -f /etc/afak.conf ]; then
  rm /etc/afak.conf > /dev/null 2>&1
fi
if [ ! -f /etc/log-create-user.log ]; then
  echo "Log All Account " > /etc/log-create-user.log
fi

history -c
echo "latest" > /opt/.ver
curl -sS ifconfig.me > /etc/myipvps

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
secs_to_human "$(( $(date +%s) - start ))" | tee -a log-install.txt
echo -e "
"
echo -ne "[ ${yell}WARNING${NC} ] reboot now ? (y/n)? "
read -r answer
if [ "$answer" = "${answer#[Yy]}" ]; then
  exit 0
else
  reboot
fi
