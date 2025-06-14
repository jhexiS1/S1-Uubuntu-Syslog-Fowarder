#!/usr/bin/env bash
# sentinelone_syslog_ng_multi_source_setup.sh
# Version: Ubuntu Edition
# Author: Adapted and enhanced by ChatGPT
# Description: Automates installation and configuration of syslog-ng on Ubuntu
#              to forward logs from multiple source IP groups to SentinelOne.

set -euo pipefail

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] This script must be run as root." >&2
  exit 1
fi

echo "=== SentinelOne Syslog-ng Multi-Source Setup (Ubuntu) ==="

# Step 1: Install dependencies
echo "[INFO] Installing packages..."
apt update
apt install -y syslog-ng-core syslog-ng-mod-http util-linux

# Step 2: Configure firewall
if command -v ufw &> /dev/null; then
  echo "[INFO] Configuring UFW rules for syslog..."
  ufw allow 514/udp
  ufw allow 5514/tcp
  ufw reload
else
  echo "[WARN] UFW not found. Please open ports 514/udp and 5514/tcp manually." >&2
fi

# Step 3: Collect source-group definitions
read -p "Enter number of source groups: " group_count
if ! [[ "$group_count" =~ ^[1-9][0-9]*$ ]]; then
  echo "[ERROR] Invalid number of groups." >&2
  exit 1
fi

declare -a config_blocks
for i in $(seq 1 "$group_count"); do
  echo "---- Configuring group #$i ----"
  # Validate group name
  while true; do
    read -p "Group name (alphanumeric & underscore only): " group_name
    if [[ "$group_name" =~ ^[A-Za-z0-9_]+$ ]]; then
      break
    else
      echo "[ERROR] Use only letters, numbers, and underscores." >&2
    fi
  done

  # Read and split IPs/CIDRs
  read -p "Enter comma-separated IPs/CIDRs for $group_name: " ip_list
  IFS=',' read -r -a ips <<< "$ip_list"
  # Build filter expression
  filter_expr="or("
  for cidr in "${ips[@]}"; do
    filter_expr+=" netmask(\"$cidr\");"
  done
  filter_expr+=" )"

  # Securely read API key
  read -s -p "SentinelOne API key for $group_name: " api_key
  echo ""
  if [[ -z "$api_key" ]]; then
    echo "[ERROR] API key cannot be empty." >&2
    exit 1
  fi

  # Read sourcetype/parser name
  read -p "Enter sourcetype/parser for $group_name: " parser_name
  if [[ -z "$parser_name" ]]; then
    echo "[ERROR] Sourcetype cannot be empty." >&2
    exit 1
  fi

  # Assemble syslog-ng config block
  config_blocks+=("filter f_$group_name {
    $filter_expr;
};

source s_$group_name {
    syslog(ip(0.0.0.0) port(514) transport(\"udp\"));
};

destination d_$group_name {
    http(
        url(\"https://ingest.us1.sentinelone.net/services/collector/raw\")
        method(\"POST\")
        headers(
            \"Authorization: ApiKey $api_key\"
            \"Content-Type: application/json\"
            \"X-Sourcetype: $parser_name\"
        )
        body(\"%MESSAGE%\")
        tls(peer-verify(optional-trust))
    );
};

log {
    source(s_$group_name);
    filter(f_$group_name);
    destination(d_$group_name);
};")
done

# Step 4: Write the consolidated config
conf_file="/etc/syslog-ng/conf.d/sentinelone_multi_source.conf"
if [[ -f "$conf_file" ]]; then
  cp "$conf_file" "${conf_file}.bak.$(date +%s)"
  echo "[INFO] Backed up existing config to ${conf_file}.bak.*"
fi

cat > "$conf_file" <<EOF
@version: 3.36
@include "scl.conf"

$(printf "%s

" "${config_blocks[@]}")
EOF

# Step 5: Restart and enable service
echo "[INFO] Restarting syslog-ng..."
systemctl restart syslog-ng
systemctl enable syslog-ng

echo "[DONE] Setup complete."
echo "Validate with: sudo syslog-ng --syntax-only"
echo "Logs: journalctl -u syslog-ng -f"
