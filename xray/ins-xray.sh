#!/bin/bash
# shellcheck disable=SC2016
set -o errexit
set -o pipefail

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
XRAY_INSTALL_COMMIT="e741a4f56d368afbb9e5be3361b40c4552d3710d"
ACME_SH_COMMIT="f39d066ced0271d87790dc426556c1e02a88c91b"
XRAY_INSTALL_URL="https://raw.githubusercontent.com/XTLS/Xray-install/${XRAY_INSTALL_COMMIT}/install-release.sh"
ACME_SH_URL="https://raw.githubusercontent.com/acmesh-official/acme.sh/${ACME_SH_COMMIT}/acme.sh"
XRAY_INSTALL_SHA256="7f70c95f6b418da8b4f4883343d602964915e28748993870fd554383afdbe555"
ACME_SH_SHA256="3c15d539f2b670040c67b596161297ef4e402a969e686ee53d5a083923e761db"
ALLOW_SELF_SIGNED_CERT="${SUPREME_ALLOW_SELF_SIGNED:-0}"

download_usr_bin() {
	local bin_name="$1"
	local remote_path="$2"
	local url="${RAW_BASE_URL}/${remote_path}"
	local local_source="${SUPREME_LOCAL_SOURCE:-}"
	local local_file=""

	if [ -n "$local_source" ]; then
		local_file="${local_source%/}/${remote_path}"
	fi

	if [ -n "$local_file" ] && [ -f "$local_file" ]; then
		cp -f "$local_file" "/usr/bin/${bin_name}"
	elif ! wget -q -O "/usr/bin/${bin_name}" "$url"; then
		echo -e "[ ${yell}ERROR${NC} ] Failed to download ${url}"
		exit 1
	fi
	chmod +x "/usr/bin/${bin_name}"
}

download_file_or_fail() {
	local url="$1"
	local dest="$2"
	local expected_sha="${3:-}"
	if ! curl -fsSL "$url" -o "$dest"; then
		echo -e "[ ${yell}ERROR${NC} ] Failed to download ${url}"
		exit 1
	fi
	if [ ! -s "$dest" ]; then
		echo -e "[ ${yell}ERROR${NC} ] Downloaded file is empty: ${dest}"
		exit 1
	fi
	if [ -n "$expected_sha" ]; then
		local actual_sha
		actual_sha="$(sha256sum "$dest" | awk '{print $1}')"
		if [ "$actual_sha" != "$expected_sha" ]; then
			echo -e "[ ${yell}ERROR${NC} ] Checksum mismatch for ${url}"
			echo -e "[ ${yell}ERROR${NC} ] Expected: ${expected_sha}"
			echo -e "[ ${yell}ERROR${NC} ] Actual  : ${actual_sha}"
			exit 1
		fi
	fi
}

generate_self_signed_cert() {
	local cert_path="/etc/xray/xray.crt"
	local key_path="/etc/xray/xray.key"
	echo -e "[ ${yell}WARN${NC} ] Falling back to self-signed certificate for ${domain}"
	openssl req -x509 -nodes -newkey rsa:2048 \
		-keyout "$key_path" \
		-out "$cert_path" \
		-days 3650 \
		-subj "/CN=${domain}" >/dev/null 2>&1
	chmod 600 "$key_path"
	chmod 644 "$cert_path"
}

handle_acme_failure() {
	local reason="$1"
	if [ "$ALLOW_SELF_SIGNED_CERT" = "1" ]; then
		echo -e "[ ${yell}WARN${NC} ] ${reason}"
		generate_self_signed_cert
	else
		echo -e "[ ${yell}ERROR${NC} ] ${reason}"
		echo -e "[ ${yell}ERROR${NC} ] Refusing implicit self-signed certificate."
		echo -e "[ ${yell}ERROR${NC} ] Set SUPREME_ALLOW_SELF_SIGNED=1 only for testing/non-production."
		exit 1
	fi
}

echo -e "
"
date
echo ""
if [ ! -s /root/domain ]; then
	echo -e "[ ${yell}ERROR${NC} ] /root/domain not found or empty"
	exit 1
fi
domain=$(</root/domain)
sleep 0.5
mkdir -p /etc/xray
echo -e "[ ${green}INFO${NC} ] Checking... "
apt install iptables iptables-persistent -y
sleep 0.5
echo -e "[ ${green}INFO$NC ] Setting time service"
timedatectl set-ntp true || true
timedatectl set-timezone Asia/Jakarta || true
sleep 0.5
echo -e "[ ${green}INFO$NC ] Installing dependencies"
apt clean all && apt update
apt install curl socat xz-utils wget apt-transport-https gnupg gnupg2 gnupg1 dnsutils lsb-release cron bash-completion ntpdate chrony zip pwgen openssl netcat-openbsd -y
ntpdate pool.ntp.org || true
for chrony_service in chronyd chrony; do
	if systemctl list-unit-files | awk '{print $1}' | grep -qx "${chrony_service}.service"; then
		echo -e "[ ${green}INFO$NC ] Enable ${chrony_service}"
		systemctl enable "${chrony_service}"
		systemctl restart "${chrony_service}"
		break
	fi
done
sleep 0.5
echo -e "[ ${green}INFO$NC ] Setting chrony tracking"
chronyc sourcestats -v || true
chronyc tracking -v || true

# install xray
sleep 0.5
echo -e "[ ${green}INFO$NC ] Downloading & Installing xray core"
mkdir -p /run/xray
# Make Folder XRay
mkdir -p /var/log/xray
chown www-data:www-data /run/xray
chown www-data:www-data /var/log/xray
touch /var/log/xray/access.log
touch /var/log/xray/error.log
touch /var/log/xray/access2.log
touch /var/log/xray/error2.log
# / / Ambil Xray Core Version Terbaru
xray_installer="$(mktemp)"
download_file_or_fail "$XRAY_INSTALL_URL" "$xray_installer" "$XRAY_INSTALL_SHA256"
bash "$xray_installer" install -u www-data
rm -f "$xray_installer"

## crt xray
systemctl stop nginx || true
mkdir -p /root/.acme.sh
download_file_or_fail "$ACME_SH_URL" /root/.acme.sh/acme.sh "$ACME_SH_SHA256"
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
if /root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256; then
	if ! ~/.acme.sh/acme.sh --installcert -d "$domain" --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc; then
		handle_acme_failure "ACME certificate install failed"
	fi
else
	handle_acme_failure "ACME certificate issue failed"
fi

# nginx renew ssl
cat >/usr/local/bin/ssl_renew.sh <<'EOF'
#!/bin/bash
if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -qx 'nginx.service'; then
	systemctl stop nginx >/dev/null 2>&1 || true
else
	/etc/init.d/nginx stop >/dev/null 2>&1 || true
fi
"/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" &> /root/renew_ssl.log
if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -qx 'nginx.service'; then
	systemctl start nginx >/dev/null 2>&1 || true
else
	/etc/init.d/nginx start >/dev/null 2>&1 || true
fi
EOF
chmod +x /usr/local/bin/ssl_renew.sh
existing_cron="$(crontab -l 2>/dev/null || true)"
if ! printf '%s\n' "$existing_cron" | grep -q 'ssl_renew.sh'; then
	{
		printf '%s\n' "$existing_cron"
		echo "15 03 */3 * * /usr/local/bin/ssl_renew.sh"
	} | crontab -
fi

mkdir -p /home/vps/public_html

# set uuid
uuid=$(</proc/sys/kernel/random/uuid)
# xray config
cat >/etc/xray/config.json <<END
{
  "log" : {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
      {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    },
   {
     "listen": "127.0.0.1",
     "port": "14016",
     "protocol": "vless",
      "settings": {
          "decryption":"none",
            "clients": [
               {
                 "id": "${uuid}"                 
#vless
             }
          ]
       },
       "streamSettings":{
         "network": "ws",
            "wsSettings": {
                "path": "/vless"
          }
        }
     },
     {
     "listen": "127.0.0.1",
     "port": "23456",
     "protocol": "vmess",
      "settings": {
            "clients": [
               {
                 "id": "${uuid}",
                 "alterId": 0
#vmess
             }
          ]
       },
       "streamSettings":{
         "network": "ws",
            "wsSettings": {
                "path": "/vmess"
          }
        }
     },
    {
      "listen": "127.0.0.1",
      "port": "25432",
      "protocol": "trojan",
      "settings": {
          "decryption":"none",		
           "clients": [
              {
                 "password": "${uuid}"
#trojanws
              }
          ],
         "udp": true
       },
       "streamSettings":{
           "network": "ws",
           "wsSettings": {
               "path": "/trojan-ws"
            }
         }
     },
    {
         "listen": "127.0.0.1",
        "port": "30300",
        "protocol": "shadowsocks",
        "settings": {
           "clients": [
           {
           "method": "aes-128-gcm",
          "password": "${uuid}"
#ssws
           }
          ],
          "network": "tcp,udp"
       },
       "streamSettings":{
          "network": "ws",
             "wsSettings": {
               "path": "/ss-ws"
           }
        }
     },	
      {
        "listen": "127.0.0.1",
     "port": "24456",
        "protocol": "vless",
        "settings": {
         "decryption":"none",
           "clients": [
             {
               "id": "${uuid}"
#vlessgrpc
             }
          ]
       },
          "streamSettings":{
             "network": "grpc",
             "grpcSettings": {
                "serviceName": "vless-grpc"
           }
        }
     },
     {
      "listen": "127.0.0.1",
     "port": "31234",
     "protocol": "vmess",
      "settings": {
            "clients": [
               {
                 "id": "${uuid}",
                 "alterId": 0
#vmessgrpc
             }
          ]
       },
       "streamSettings":{
         "network": "grpc",
            "grpcSettings": {
                "serviceName": "vmess-grpc"
          }
        }
     },
     {
        "listen": "127.0.0.1",
     "port": "33456",
        "protocol": "trojan",
        "settings": {
          "decryption":"none",
             "clients": [
               {
                 "password": "${uuid}"
#trojangrpc
               }
           ]
        },
         "streamSettings":{
         "network": "grpc",
           "grpcSettings": {
               "serviceName": "trojan-grpc"
         }
      }
   },
   {
    "listen": "127.0.0.1",
    "port": "30310",
    "protocol": "shadowsocks",
    "settings": {
        "clients": [
          {
             "method": "aes-128-gcm",
             "password": "${uuid}"
#ssgrpc
           }
         ],
           "network": "tcp,udp"
      },
    "streamSettings":{
     "network": "grpc",
        "grpcSettings": {
           "serviceName": "ss-grpc"
          }
       }
    }	
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },
      {
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": [
          "bittorrent"
        ]
      }
    ]
  },
  "stats": {},
  "api": {
    "services": [
      "StatsService"
    ],
    "tag": "api"
  },
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink" : true,
      "statsOutboundDownlink" : true
    }
  }
}
END
rm -rf /etc/systemd/system/xray.service.d
rm -rf /etc/systemd/system/xray@.service
cat <<EOF >/etc/systemd/system/xray.service
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=www-data
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target

EOF
cat >/etc/systemd/system/runn.service <<EOF
[Unit]
Description=Mantap-Sayang
After=network.target

[Service]
Type=simple
ExecStartPre=-/usr/bin/mkdir -p /var/run/xray
ExecStart=/usr/bin/chown www-data:www-data /var/run/xray
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

#nginx config
cat >/etc/nginx/conf.d/xray.conf <<EOF
    server {
             listen 80;
             listen 443 ssl http2 reuseport;
             server_name *.$domain;
             ssl_certificate /etc/xray/xray.crt;
             ssl_certificate_key /etc/xray/xray.key;
             ssl_ciphers EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES:!MD5;
             ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
             root /home/vps/public_html;
        }
EOF
sed -i '$ ilocation = /vless' /etc/nginx/conf.d/xray.conf
sed -i '$ i{' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_pass http://127.0.0.1:14016;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_http_version 1.1;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Upgrade \$http_upgrade;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Connection "upgrade";' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ i}' /etc/nginx/conf.d/xray.conf

sed -i '$ ilocation = /vmess' /etc/nginx/conf.d/xray.conf
sed -i '$ i{' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_pass http://127.0.0.1:23456;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_http_version 1.1;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Upgrade \$http_upgrade;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Connection "upgrade";' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ i}' /etc/nginx/conf.d/xray.conf

sed -i '$ ilocation = /trojan-ws' /etc/nginx/conf.d/xray.conf
sed -i '$ i{' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_pass http://127.0.0.1:25432;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_http_version 1.1;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Upgrade \$http_upgrade;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Connection "upgrade";' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ i}' /etc/nginx/conf.d/xray.conf

sed -i '$ ilocation = /ss-ws' /etc/nginx/conf.d/xray.conf
sed -i '$ i{' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_pass http://127.0.0.1:30300;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_http_version 1.1;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Upgrade \$http_upgrade;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Connection "upgrade";' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ i}' /etc/nginx/conf.d/xray.conf

sed -i '$ ilocation /' /etc/nginx/conf.d/xray.conf
sed -i '$ i{' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_pass http://127.0.0.1:700;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_http_version 1.1;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Upgrade \$http_upgrade;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Connection "upgrade";' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ i}' /etc/nginx/conf.d/xray.conf

sed -i '$ ilocation ^~ /vless-grpc' /etc/nginx/conf.d/xray.conf
sed -i '$ i{' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_pass grpc://127.0.0.1:24456;' /etc/nginx/conf.d/xray.conf
sed -i '$ i}' /etc/nginx/conf.d/xray.conf

sed -i '$ ilocation ^~ /vmess-grpc' /etc/nginx/conf.d/xray.conf
sed -i '$ i{' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_pass grpc://127.0.0.1:31234;' /etc/nginx/conf.d/xray.conf
sed -i '$ i}' /etc/nginx/conf.d/xray.conf

sed -i '$ ilocation ^~ /trojan-grpc' /etc/nginx/conf.d/xray.conf
sed -i '$ i{' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_pass grpc://127.0.0.1:33456;' /etc/nginx/conf.d/xray.conf
sed -i '$ i}' /etc/nginx/conf.d/xray.conf

sed -i '$ ilocation ^~ /ss-grpc' /etc/nginx/conf.d/xray.conf
sed -i '$ i{' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_pass grpc://127.0.0.1:30310;' /etc/nginx/conf.d/xray.conf
sed -i '$ i}' /etc/nginx/conf.d/xray.conf

echo -e "${yell}[SERVICE]$NC Restart All service"
systemctl daemon-reload
sleep 0.5
echo -e "[ ${green}ok${NC} ] Enable & restart xray "
systemctl enable xray
systemctl restart xray
systemctl restart nginx
systemctl enable runn
systemctl restart runn

cd /usr/bin/
download_targets=(
	"add-ws:xray/add-ws.sh"
	"trialvmess:xray/trialvmess.sh"
	"renew-ws:xray/renew-ws.sh"
	"del-ws:xray/del-ws.sh"
	"cek-ws:xray/cek-ws.sh"
	"add-vless:xray/add-vless.sh"
	"trialvless:xray/trialvless.sh"
	"renew-vless:xray/renew-vless.sh"
	"del-vless:xray/del-vless.sh"
	"cek-vless:xray/cek-vless.sh"
	"add-tr:xray/add-tr.sh"
	"trialtrojan:xray/trialtrojan.sh"
	"del-tr:xray/del-tr.sh"
	"renew-tr:xray/renew-tr.sh"
	"cek-tr:xray/cek-tr.sh"
	"add-ssws:xray/add-ssws.sh"
	"trialssws:xray/trialssws.sh"
	"del-ssws:xray/del-ssws.sh"
	"renew-ssws:xray/renew-ssws.sh"
)

for target in "${download_targets[@]}"; do
	name="${target%%:*}"
	path="${target#*:}"
	download_usr_bin "$name" "$path"
done

sleep 0.5
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
yellow "xray/Vmess"
yellow "xray/Vless"

if [ -s /root/domain ]; then
	install -m 0644 /root/domain /etc/xray/domain
else
	echo -e "[ ${yell}WARN${NC} ] /root/domain is missing, skip copying domain file"
fi
if [ -f /root/scdomain ]; then
	rm /root/scdomain >/dev/null 2>&1
fi
clear >/dev/null 2>&1 || true
rm -f ins-xray.sh
