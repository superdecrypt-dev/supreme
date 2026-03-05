#!/bin/bash
#
# ==================================================
set -o errexit
set -o pipefail

# etc
apt install netfilter-persistent -y
apt-get remove --purge ufw firewalld -y
apt install -y screen curl jq bzip2 gzip vnstat coreutils rsyslog iftop zip unzip git apt-transport-https build-essential snapd

# initializing var
export DEBIAN_FRONTEND=noninteractive
green='\e[0;32m'
yell='\e[1;33m'
NC='\e[0m'
resolve_supreme_ref() {
	if [ -n "${SUPREME_REF:-}" ]; then
		echo "$SUPREME_REF"
		return
	fi

	if [ -s /opt/.supreme_ref ]; then
		cat /opt/.supreme_ref
		return
	fi

	local script_dir
	script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	if command -v git >/dev/null 2>&1 && git -C "$script_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		git -C "$script_dir" rev-parse HEAD
		return
	fi

	return 1
}

SUPREME_REF="$(resolve_supreme_ref || true)"
if [ -z "$SUPREME_REF" ]; then
	echo -e "[ ${yell}ERROR${NC} ] SUPREME_REF is not set. Run setup.sh first or export SUPREME_REF."
	exit 1
fi
RAW_BASE_URL="https://raw.githubusercontent.com/superdecrypt-dev/supreme/${SUPREME_REF}"

# helpers
append_line_once() {
	local file="$1"
	local line="$2"
	grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >>"$file"
}

insert_rc_local_once() {
	local line="$1"
	grep -qxF "$line" /etc/rc.local 2>/dev/null || sed -i "\$ i\\${line}" /etc/rc.local
}

insert_before_match_once() {
	local file="$1"
	local line="$2"

	grep -qxF "$line" "$file" 2>/dev/null && return 0

	if grep -q '^Match[[:space:]]' "$file"; then
		awk -v new_line="$line" '
      BEGIN { inserted = 0 }
      !inserted && /^Match[[:space:]]/ { print new_line; inserted = 1 }
      { print }
      END { if (!inserted) print new_line }
    ' "$file" >"${file}.tmp" && mv "${file}.tmp" "$file"
	else
		echo "$line" >>"$file"
	fi
}

set_or_append_kv() {
	local file="$1"
	local key="$2"
	local value="$3"

	if grep -qE "^[#[:space:]]*${key}=" "$file"; then
		sed -i -E "s|^[#[:space:]]*${key}=.*|${key}=${value}|" "$file"
	else
		echo "${key}=${value}" >>"$file"
	fi
}

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

download_file() {
	local dest="$1"
	local remote_path="$2"
	local url="${RAW_BASE_URL}/${remote_path}"
	local local_source="${SUPREME_LOCAL_SOURCE:-}"
	local local_file=""

	if [ -n "$local_source" ]; then
		local_file="${local_source%/}/${remote_path}"
	fi

	if [ -n "$local_file" ] && [ -f "$local_file" ]; then
		cp -f "$local_file" "$dest"
		return
	fi

	if ! secure_download "$url" "$dest"; then
		echo -e "[ ${yell}ERROR${NC} ] Failed to download ${url}"
		exit 1
	fi
	if [ ! -s "$dest" ]; then
		echo -e "[ ${yell}ERROR${NC} ] Downloaded file is empty: ${dest}"
		exit 1
	fi
}

download_usr_bin() {
	local bin_name="$1"
	local remote_path="$2"
	download_file "/usr/bin/${bin_name}" "$remote_path"
	chmod +x "/usr/bin/${bin_name}"
}

restart_service_if_present() {
	local service_name="$1"
	local label="$2"
	if command -v systemctl >/dev/null 2>&1; then
		if systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -qx "${service_name}.service"; then
			if ! systemctl restart "${service_name}.service" >/dev/null 2>&1; then
				echo -e "[ ${yell}WARN${NC} ] Failed to restart ${label}, continuing"
			fi
			return
		fi
	fi

	if [ -x "/etc/init.d/${service_name}" ]; then
		if ! /etc/init.d/"${service_name}" restart >/dev/null 2>&1; then
			echo -e "[ ${yell}WARN${NC} ] Failed to restart ${label}, continuing"
		fi
	else
		echo -e "[ ${yell}WARN${NC} ] ${label} not installed, skipping restart"
	fi
}

install_speedtest_via_snap() {
	echo -e "[ ${green}INFO${NC} ] Installing speedtest via snap"

	systemctl enable --now snapd.socket >/dev/null 2>&1 || true
	systemctl enable --now snapd.service >/dev/null 2>&1 || true

	if ! command -v snap >/dev/null 2>&1; then
		echo -e "[ ${yell}WARN${NC} ] snap command is not available after installing snapd"
		return
	fi

	if ! snap list speedtest >/dev/null 2>&1; then
		if ! snap install speedtest; then
			echo -e "[ ${yell}WARN${NC} ] Failed to install speedtest snap, continuing"
			return
		fi
	fi

	if [ -x /snap/bin/speedtest ]; then
		ln -sf /snap/bin/speedtest /usr/bin/speedtest
	else
		echo -e "[ ${yell}WARN${NC} ] /snap/bin/speedtest not found after snap install"
	fi
}

#detail nama perusahaan
country=ID
state=Indonesia
locality=Jakarta
organization=none
organizationalunit=none
commonname=none
email=none

# simple password minimal
pam_enc_file=$(mktemp)
pam_dec_file=$(mktemp)
if ! download_file "$pam_enc_file" "ssh/password"; then
	echo "Failed to download PAM policy payload"
	rm -f "$pam_enc_file" "$pam_dec_file"
	exit 1
fi
if ! openssl aes-256-cbc -d -a -pass pass:scvps07gg -pbkdf2 -in "$pam_enc_file" -out "$pam_dec_file"; then
	echo "Failed to decrypt PAM policy payload"
	rm -f "$pam_enc_file" "$pam_dec_file"
	exit 1
fi
if [ ! -s "$pam_dec_file" ]; then
	echo "Decrypted PAM policy is empty, aborting"
	rm -f "$pam_enc_file" "$pam_dec_file"
	exit 1
fi
if [ -f /etc/pam.d/common-password ]; then
	cp -f /etc/pam.d/common-password "/etc/pam.d/common-password.bak.$(date +%s)"
fi
install -m 0644 "$pam_dec_file" /etc/pam.d/common-password
rm -f "$pam_enc_file" "$pam_dec_file"

# go to root
cd

# Edit file /etc/systemd/system/rc-local.service
cat >/etc/systemd/system/rc-local.service <<-END
	[Unit]
	Description=/etc/rc.local
	ConditionPathExists=/etc/rc.local
	[Service]
	Type=forking
	ExecStart=/etc/rc.local start
	TimeoutSec=0
	StandardOutput=tty
	RemainAfterExit=yes
	SysVStartPriority=99
	[Install]
	WantedBy=multi-user.target
END

# nano /etc/rc.local
cat >/etc/rc.local <<-END
	#!/bin/sh -e
	# rc.local
	# By default this script does nothing.
	exit 0
END

# Ubah izin akses
chmod +x /etc/rc.local

# enable rc local
systemctl enable rc-local
systemctl start rc-local.service

# disable ipv6
echo 1 >/proc/sys/net/ipv6/conf/all/disable_ipv6
insert_rc_local_once "echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6"

#update
apt update -y
apt upgrade -y
apt dist-upgrade -y
apt-get remove --purge exim4 -y

#install shc
apt -y install shc

#figlet
apt-get install figlet ruby -y
gem install lolcat

# set time GMT +7
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# set locale
sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config

# install webserver
apt -y install nginx
cd
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default
download_file /etc/nginx/nginx.conf "ssh/nginx.conf"
mkdir -p /home/vps/public_html
restart_service_if_present "nginx" "nginx"

# install badvpn
cd
pkill -f "badvpn-udpgw --listen-addr 127.0.0.1:" >/dev/null 2>&1 || true
tmp_badvpn_bin="$(mktemp)"
download_file "$tmp_badvpn_bin" "ssh/newudpgw"
install -m 0755 "$tmp_badvpn_bin" /usr/bin/badvpn-udpgw
rm -f "$tmp_badvpn_bin"
for port in 7100 7200 7300 7400 7500 7600 7700 7800 7900; do
	insert_rc_local_once "screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:${port} --max-clients 500"
	screen -dmS badvpn badvpn-udpgw --listen-addr "127.0.0.1:${port}" --max-clients 500
done

# setting port ssh
cd
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
if grep -q '^PasswordAuthentication[[:space:]]' /etc/ssh/sshd_config; then
	sed -i 's/^PasswordAuthentication[[:space:]].*/PasswordAuthentication yes/' /etc/ssh/sshd_config
else
	insert_before_match_once /etc/ssh/sshd_config "PasswordAuthentication yes"
fi
for ssh_port in 22 200 500 40000 51443 58080; do
	insert_before_match_once /etc/ssh/sshd_config "Port ${ssh_port}"
done
restart_service_if_present "ssh" "ssh"

echo "=== Install Dropbear ==="
# install dropbear
apt -y install dropbear
set_or_append_kv /etc/default/dropbear "NO_START" "0"
set_or_append_kv /etc/default/dropbear "DROPBEAR_PORT" "143"
set_or_append_kv /etc/default/dropbear "DROPBEAR_EXTRA_ARGS" "\"-p 50000 -p 109 -p 110 -p 69\""
append_line_once /etc/shells "/bin/false"
append_line_once /etc/shells "/usr/sbin/nologin"
restart_service_if_present "dropbear" "dropbear"

cd
# install stunnel
apt install stunnel4 -y
cat >/etc/stunnel/stunnel.conf <<-END
	foreground = yes
	cert = /etc/stunnel/stunnel.pem
	client = no
	socket = a:SO_REUSEADDR=1
	socket = l:TCP_NODELAY=1
	socket = r:TCP_NODELAY=1

	[dropbear-ssh]
	accept = 222
	connect = 127.0.0.1:22

	[dropbear-alt]
	accept = 777
	connect = 127.0.0.1:109

	[ws-stunnel]
	accept = 2096
	connect = 700

	[openvpn]
	accept = 442
	connect = 127.0.0.1:1194

END

# make a certificate
openssl genrsa -out key.pem 2048
openssl req -new -x509 -key key.pem -out cert.pem -days 1095 \
	-subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"
cat key.pem cert.pem >>/etc/stunnel/stunnel.pem
chmod 600 /etc/stunnel/stunnel.pem

# konfigurasi stunnel
set_or_append_kv /etc/default/stunnel4 "ENABLED" "1"
if command -v systemctl >/dev/null 2>&1; then
	systemctl disable --now stunnel4.service >/dev/null 2>&1 || true
	pkill -x stunnel4 >/dev/null 2>&1 || true
	cat >/etc/systemd/system/supreme-stunnel.service <<'END'
[Unit]
Description=Supreme Stunnel Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStartPre=-/usr/bin/pkill -x stunnel4
ExecStart=/usr/bin/stunnel4 /etc/stunnel/stunnel.conf
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
END
	systemctl daemon-reload
	if ! systemctl enable --now supreme-stunnel.service >/dev/null 2>&1; then
		echo -e "[ ${yell}WARN${NC} ] Failed to enable/start Supreme Stunnel service"
	fi
else
	restart_service_if_present "stunnel4" "stunnel4"
fi

# install fail2ban
apt -y install fail2ban

# blokir torrent
iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP
iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP
iptables -A FORWARD -m string --string "find_node" --algo bm -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP
iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
iptables -A FORWARD -m string --algo bm --string "torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce" -j DROP
iptables -A FORWARD -m string --algo bm --string "info_hash" -j DROP
iptables-save >/etc/iptables.up.rules
iptables-restore -t </etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload

# download script
cd /usr/bin || exit 1
download_targets=(
	"menu:menu/menu.sh"
	"m-vmess:menu/m-vmess.sh"
	"m-vless:menu/m-vless.sh"
	"running:menu/running.sh"
	"clearcache:menu/clearcache.sh"
	"m-ssws:menu/m-ssws.sh"
	"m-trojan:menu/m-trojan.sh"
	"m-sshovpn:menu/m-sshovpn.sh"
	"usernew:ssh/usernew.sh"
	"trial:ssh/trial.sh"
	"renew:ssh/renew.sh"
	"hapus:ssh/hapus.sh"
	"cek:ssh/cek.sh"
	"member:ssh/member.sh"
	"delete:ssh/delete.sh"
	"autokill:ssh/autokill.sh"
	"ceklim:ssh/ceklim.sh"
	"tendang:ssh/tendang.sh"
	"m-system:menu/m-system.sh"
	"m-domain:menu/m-domain.sh"
	"add-host:ssh/add-host.sh"
	"certv2ray:xray/certv2ray.sh"
	"auto-reboot:menu/auto-reboot.sh"
	"restart:menu/restart.sh"
	"bw:menu/bw.sh"
	"m-tcp:menu/tcp.sh"
	"xp:ssh/xp.sh"
)

for target in "${download_targets[@]}"; do
	name="${target%%:*}"
	path="${target#*:}"
	download_usr_bin "$name" "$path"
done
install_speedtest_via_snap
cd

cat >/etc/cron.d/re_otm <<-END
	SHELL=/bin/sh
	PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
	0 2 * * * root /sbin/reboot
END

cat >/etc/cron.d/xp_otm <<-END
	SHELL=/bin/sh
	PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
	0 0 * * * root /usr/bin/xp
END

cat >/home/re_otm <<-END
	7
END

service cron restart >/dev/null 2>&1

# remove unnecessary files
sleep 0.5
echo -e "[ ${green}INFO$NC ] Clearing trash"
apt autoclean -y >/dev/null 2>&1

if dpkg -s unscd >/dev/null 2>&1; then
	apt -y remove --purge unscd >/dev/null 2>&1
fi

apt-get -y --purge remove samba* >/dev/null 2>&1
apt-get -y --purge remove apache2* >/dev/null 2>&1
apt-get -y --purge remove bind9* >/dev/null 2>&1
apt-get -y remove sendmail* >/dev/null 2>&1
apt autoremove -y >/dev/null 2>&1
# finishing
cd
chown -R www-data:www-data /home/vps/public_html
sleep 0.5
echo -e "${yell}[SERVICE]$NC Restart All service SSH & OVPN"
restart_service_if_present nginx "Nginx"
sleep 0.5
echo -e "[ ${green}ok${NC} ] Restarting nginx"
restart_service_if_present openvpn "OpenVPN"
sleep 0.5
echo -e "[ ${green}ok${NC} ] Restarting ssh "
restart_service_if_present ssh "SSH"
sleep 0.5
echo -e "[ ${green}ok${NC} ] Restarting dropbear "
restart_service_if_present dropbear "Dropbear"
sleep 0.5
echo -e "[ ${green}ok${NC} ] Restarting fail2ban "
restart_service_if_present fail2ban "Fail2ban"
sleep 0.5
echo -e "[ ${green}ok${NC} ] Restarting stunnel4 "
restart_service_if_present supreme-stunnel "Stunnel4"
sleep 0.5
echo -e "[ ${green}ok${NC} ] Restarting vnstat "
restart_service_if_present vnstat "Vnstat"
sleep 0.5
echo -e "[ ${green}ok${NC} ] Restarting squid "
restart_service_if_present squid "Squid"

pkill -f "badvpn-udpgw --listen-addr 127.0.0.1:" >/dev/null 2>&1 || true
for port in 7100 7200 7300 7400 7500 7600 7700 7800 7900; do
	screen -dmS badvpn badvpn-udpgw --listen-addr "127.0.0.1:${port}" --max-clients 500
done
history -c
append_line_once /etc/profile "unset HISTFILE"

rm -f /root/key.pem
rm -f /root/cert.pem
rm -f /root/ssh-vpn.sh

# finihsing
clear >/dev/null 2>&1 || true
