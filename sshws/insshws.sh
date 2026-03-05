#!/bin/bash
#installer Websocker tunneling
set -o errexit
set -o nounset
set -o pipefail

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
	echo "SUPREME_REF is not set. Run setup.sh first or export SUPREME_REF."
	exit 1
fi
RAW_BASE_URL="https://raw.githubusercontent.com/superdecrypt-dev/supreme/${SUPREME_REF}"

cd

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

	if ! wget -q -O "$dest" "$url"; then
		echo "Failed to download ${url}"
		exit 1
	fi
}

#Install Script Websocket-SSH Python
download_file /usr/local/bin/ws-dropbear "sshws/ws-dropbear"
download_file /usr/local/bin/ws-stunnel "sshws/ws-stunnel"

#izin permision
chmod +x /usr/local/bin/ws-dropbear
chmod +x /usr/local/bin/ws-stunnel

#System Dropbear Websocket-SSH Python
download_file /etc/systemd/system/ws-dropbear.service "sshws/ws-dropbear.service"

#System SSL/TLS Websocket-SSH Python
download_file /etc/systemd/system/ws-stunnel.service "sshws/ws-stunnel.service"

#restart service
systemctl daemon-reload

#Enable & Start & Restart ws-dropbear service
systemctl enable ws-dropbear.service
systemctl restart ws-dropbear.service

#Enable & Start & Restart ws-openssh service
systemctl enable ws-stunnel.service
systemctl restart ws-stunnel.service
