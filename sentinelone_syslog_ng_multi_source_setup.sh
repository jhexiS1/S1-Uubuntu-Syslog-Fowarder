#!/bin/bash

# sentinelone_syslog_ng_multi_source_setup.sh
# Version: Ubuntu Edition
# Author: Adapted for Ubuntu by PurpleOne GPT
# Description: Automates setup of syslog-ng on Ubuntu to forward logs from multiple sources to SentinelOne

set -e

echo "=== SentinelOne Syslog-ng Multi-Source Setup (Ubuntu) ==="

# --- Step 1: System Preparation ---
echo "[INFO] Updating system and installing dependencies..."
sudo apt update
sudo apt install -y syslog-ng-core syslog-ng-mod-http util-linux

# Remove rsyslog if it's installed to avoid conflict with syslog-ng
if dpkg -l | grep -q rsyslog; then
  echo "[INFO] Removing rsyslog to prevent conflict..."
  sudo apt remove -y rsyslog
fi

# --- Step 2: Firewall Configuration ---
echo "[INFO] Configuring firewall to allow syslog ports..."
sudo ufw allow 514/udp
sudo ufw allow 5514/tcp
sudo ufw reload

# --- Step 3: Interactive Configuration for Log Sources ---
echo "[INFO] Starting interactive setup for log source groups..."
read -p "Enter number of log source groups to configure: " group_count

config_blocks=()

for ((i=1; i<=group_count; i++)); do
  echo "--- Configuring group #$i ---"
  read -p "  Group Name (no spaces): " group_name
  read -p "  Source IPs or CIDRs (space-separated): " group_ips
  read -sp "  SentinelOne API Key: " api_key
  echo
  read -p "  SentinelOne Sourcetype (parser name): " sourcetype

  config_blocks+=("
destination d_$group_name {
  http(
    url(\"https://ingest.us1.sentinelone.net/services/collector/raw?sourcetype=$sourcetype\")
    headers(\"Authorization: $api_key\")
    method(\"POST\")
    body-mode(\"json\")
  );
};

filter f_$group_name {
  netmask(\"$group_ips\");
};

log {
  source(s_net);
  filter(f_$group_name);
  destination(d_$group_name);
  flags(final);
};")
done

# --- Step 4: syslog-ng Configuration File ---
echo "[INFO] Generating syslog-ng configuration..."
sudo tee /etc/syslog-ng/conf.d/sentinelone_multi_source.conf > /dev/null <<EOF
@version: 3.36
@include "scl.conf"

source s_net {
  network(ip(\"0.0.0.0\") port(514) transport(\"udp\"));
  network(ip(\"0.0.0.0\") port(5514) transport(\"tcp\"));
};

$(printf "%s\n\n" "${config_blocks[@]}")
EOF

# --- Step 5: Restart syslog-ng ---
echo "[INFO] Restarting syslog-ng service..."
sudo systemctl restart syslog-ng
sudo systemctl enable syslog-ng

# --- Final Step ---
echo "[DONE] Setup complete. Syslog-ng is now configured to forward logs to SentinelOne."
echo "Check /var/log/syslog or /var/log/syslog-ng for troubleshooting if needed."
