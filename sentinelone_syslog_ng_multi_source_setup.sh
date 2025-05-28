#!/usr/bin/env bash
# sentinelone_syslog_ng_multi_source_setup.sh
# Version: Ubuntu Edition – Revised 2
# Description: Installs and configures syslog-ng on Ubuntu to forward logs
#              from multiple source IP groups—each on its own UDP port—
#              to a SentinelOne HTTP ingestion endpoint.

set -euo pipefail

# 1. Root check
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Please run as root." >&2
  exit 1
fi

echo "=== SentinelOne Syslog-NG Multi-Source Setup (Ubuntu) ==="

# 2. Ingestion endpoint
read -p "Enter full SentinelOne HTTP ingestion endpoint URL: " ingest_endpoint
if [[ -z "$ingest_endpoint" ]]; then
  echo "[ERROR] Endpoint cannot be empty." >&2
  exit 1
fi

# 3. Add syslog-ng OSE repo & install
ubuntu_codename=$(lsb_release -cs)
echo "[INFO] Adding syslog-ng OSE repository for Ubuntu ${ubuntu_codename}..."
wget -qO - https://ose-repo.syslog-ng.com/apt/syslog-ng-ose-pub.asc | apt-key add -
echo "deb https://ose-repo.syslog-ng.com/apt/ stable ubuntu-${ubuntu_codename}" \
  | tee /etc/apt/sources.list.d/syslog-ng-ose.list

echo "[INFO] Updating package lists..."
apt-get update

echo "[INFO] Installing syslog-ng-core, syslog-ng-scl, syslog-ng-mod-http, util-linux..."
apt-get install -y syslog-ng-core syslog-ng-scl syslog-ng-mod-http util-linux

# 4. Source-group prompts
read -p "Enter number of source groups: " group_count
if ! [[ "$group_count" =~ ^[1-9][0-9]*$ ]]; then
  echo "[ERROR] Must be a positive integer." >&2
  exit 1
fi

declare -a config_blocks
declare -a udp_ports_array

for i in $(seq 1 "$group_count"); do
  echo "--- Group #$i ---"
  # a) Name
  while true; do
    read -p "Group name (alnum & underscores only): " group_name
    [[ "$group_name" =~ ^[A-Za-z0-9_]+$ ]] && break
    echo "[ERROR] Invalid name." >&2
  done

  # b) UDP port (unique, 1–65535)
  while true; do
    read -p "Unique UDP port for $group_name: " udp_port
    if [[ "$udp_port" =~ ^[0-9]+$ ]] && ((udp_port>=1 && udp_port<=65535)); then
      port_ok=true
      for p in "${udp_ports_array[@]}"; do
        [[ "$p" == "$udp_port" ]] && port_ok=false
      done
      $port_ok && { udp_ports_array+=("$udp_port"); break; }
      echo "[ERROR] Port $udp_port already used." >&2
    else
      echo "[ERROR] Must be 1–65535." >&2
    fi
  done

  # c) IPs/CIDRs
  read -p "Enter comma-separated IPs/CIDRs: " ip_list
  IFS=',' read -r -a ips <<< "$ip_list"
  filter_expr="or("
  for cidr in "${ips[@]}"; do
    filter_expr+=" netmask(\"$cidr\");"
  done
  filter_expr+=" )"

  # d) API key
  read -s -p "SentinelOne API key: " api_key; echo
  [[ -n "$api_key" ]] || { echo "[ERROR] API key required." >&2; exit 1; }

  # e) Sourcetype/parser
  read -p "Sourcetype/parser name: " parser_name
  [[ -n "$parser_name" ]] || { echo "[ERROR] Sourcetype required." >&2; exit 1; }

  # f) Assemble config block
  config_blocks+=( "
filter f_${group_name} { ${filter_expr}; };

source s_${group_name} {
  syslog(ip(0.0.0.0) port(${udp_port}) transport(\"udp\"));
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

log { source(s_${group_name}); filter(f_${group_name}); destination(d_${group_name}); };
" )
done

# 5. UFW rules
if command -v ufw &>/dev/null; then
  echo "[INFO] Configuring UFW..."
  for port in "${udp_ports_array[@]}"; do
    echo "  Allowing UDP $port"
    ufw allow "${port}/udp"
  done
  echo "  Allowing TCP 5514"
  ufw allow 5514/tcp
  ufw reload
else
  echo "[WARN] UFW not installed. Manually open UDP ports: ${udp_ports_array[*]} and TCP 5514." >&2
fi

# 6. Write syslog-ng config
conf="/etc/syslog-ng/conf.d/sentinelone_multi_source.conf"
if [[ -f "$conf" ]]; then
  bak="${conf}.bak.$(date +%s)"
  cp "$conf" "$bak"
  echo "[INFO] Backed up old config → $bak"
fi

echo "[INFO] Writing new config to $conf..."
{
  echo "@version: 3.36"
  echo "@include \"scl.conf\""
  echo
  for blk in "${config_blocks[@]}"; do
    echo "$blk"
  done
} > "$conf"

# 7. Validate & reload
echo "[INFO] Validating syslog-ng configuration..."
if syslog-ng --syntax-only; then
  echo "[INFO] Syntax OK. Reloading service..."
  if systemctl reload syslog-ng; then
    echo "[INFO] syslog-ng reloaded."
  else
    echo "[INFO] Reload failed; restarting."
    systemctl restart syslog-ng
  fi
else
  echo "[ERROR] Syntax error! New config NOT applied." >&2
  echo "[INFO] Restore previous from backup if needed." >&2
  exit 1
fi

echo "=== Setup Complete ==="
echo "Check live logs with: sudo journalctl -u syslog-ng -f"
