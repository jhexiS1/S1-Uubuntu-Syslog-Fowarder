#!/usr/bin/env bash
# sentinelone_syslog_ng_multi_source_setup.sh
# Version: Ubuntu Edition
# Author: Adapted by ChatGPT
# Description: Automates installation and configuration of syslog-ng on Ubuntu
#              to forward logs from multiple source IP groups to a SentinelOne HTTP ingestion endpoint.

set -euo pipefail

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] This script must be run as root." >&2
  exit 1
fi

echo "=== SentinelOne Syslog-ng Multi-Source Setup (Ubuntu) ==="

# Prompt for ingestion endpoint
read -p "Enter SentinelOne HTTP ingestion endpoint (full URL): " ingest_endpoint
if [[ -z "$ingest_endpoint" ]]; then
  echo "[ERROR] Ingestion endpoint cannot be empty." >&2
  exit 1
fi

# Install dependencies
echo "[INFO] Installing packages..."
apt update
apt install -y syslog-ng-core syslog-ng-mod-http util-linux

# Configure firewall
if command -v ufw &> /dev/null; then
  echo "[INFO] Configuring UFW rules..."
  ufw allow 514/udp
  ufw allow 5514/tcp
  ufw reload
else
  echo "[WARN] UFW not found; open ports 514/udp and 5514/tcp manually." >&2
fi

# Prompt for number of source groups
read -p "Enter number of source groups: " group_count
if ! [[ "$group_count" =~ ^[1-9][0-9]*$ ]]; then
  echo "[ERROR] Invalid number of groups." >&2
  exit 1
fi

declare -a config_blocks
for i in $(seq 1 "$group_count"); do
  echo "---- Configuring group #$i ----"
  while true; do
    read -p "Group name (alphanumeric & underscores only): " group_name
    if [[ "$group_name" =~ ^[A-Za-z0-9_]+$ ]]; then
      break
    else
      echo "[ERROR] Invalid group name." >&2
    fi
  done

  read -p "Enter comma-separated IPs/CIDRs for $group_name: " ip_list
  IFS=',' read -r -a ips <<< "$ip_list"
  filter_expr="or("
  for cidr in "${ips[@]}"; do
    filter_expr+=" netmask(\"${cidr}\");"
  done
  filter_expr+=" )"

  read -s -p "SentinelOne API key for $group_name: " api_key; echo ""
  if [[ -z "$api_key" ]]; then
    echo "[ERROR] API key cannot be empty." >&2
    exit 1
  fi

  read -p "Enter sourcetype/parser for $group_name: " parser_name
  if [[ -z "$parser_name" ]]; then
    echo "[ERROR] Sourcetype cannot be empty." >&2
    exit 1
  fi

  config_blocks+=( "filter f_${group_name} {
    ${filter_expr};
};

source s_${group_name} {
    syslog(ip(0.0.0.0) port(514) transport(\"udp\"));
};

destination d_${group_name} {
    http(
        url(\"${ingest_endpoint}\")
        method(\"POST\")
        headers(
            \"Authorization: ApiKey ${api_key}\"
            \"Content-Type: application/json\"
            \"X-Sourcetype: ${parser_name}\"
        )
        body(\"%MESSAGE%\")
        tls(peer-verify(optional-trust))
    );
};

log {
    source(s_${group_name});
    filter(f_${group_name});
    destination(d_${group_name});
};" )
done

conf_file="/etc/syslog-ng/conf.d/sentinelone_multi_source.conf"
if [[ -f "$conf_file" ]]; then
  cp "$conf_file" "${conf_file}.bak.$(date +%s)"
  echo "[INFO] Backed up existing config."
fi

cat > "$conf_file" <<EOF
@version: 3.36
@include "scl.conf"

$(printf "%s

" "${config_blocks[@]}")
EOF

echo "[INFO] Restarting syslog-ng..."
systemctl restart syslog-ng
systemctl enable syslog-ng

echo "[DONE] Setup complete."
echo "Validate: sudo syslog-ng --syntax-only"
echo "Logs: sudo journalctl -u syslog-ng -f"
