# SentinelOne Syslog-NG Multi-Source Setup (Ubuntu)

## Overview
This project provides a shell script to automate the configuration of an Ubuntu-based syslog-ng server. The server collects logs from multiple sources and forwards them to SentinelOne's ingestion endpoint using different API keys and parsers per source group.

## Features
- Automatically installs required packages and removes conflicting ones.
- Configures firewall rules to allow syslog traffic on UDP 514 and TCP 5514.
- Prompts user to define multiple source groups with:
  - Group name
  - IP ranges
  - SentinelOne API key (secure input)
  - SentinelOne sourcetype (parser name)
- Generates `/etc/syslog-ng/conf.d/sentinelone_multi_source.conf` dynamically.
- Restarts and enables syslog-ng service.

## Requirements
- Ubuntu server with internet access.
- `sudo` or root privileges.
- Knowledge of source IP ranges and corresponding SentinelOne API keys & sourcetypes.

## Usage
1. **Clone the Repository**
   ```bash
   git clone https://github.com/your-org/sentinelone-syslog-ng-setup.git
   cd sentinelone-syslog-ng-setup
   ```

2. **Make Script Executable**
   ```bash
   chmod +x sentinelone_syslog_ng_multi_source_setup.sh
   ```

3. **Run the Script**
   ```bash
   ./sentinelone_syslog_ng_multi_source_setup.sh
   ```

4. **Follow Prompts**
   - Enter number of log groups.
   - For each group, provide:
     - Group name (e.g., "firewalls")
     - Space-separated IPs or CIDRs
     - API key (hidden input)
     - Sourcetype (e.g., `s_palo_5514`, `s_syslog`)

5. **Verify and Monitor**
   - Check `/etc/syslog-ng/conf.d/sentinelone_multi_source.conf`.
   - Logs are typically found in `/var/log/syslog` or `/var/log/syslog-ng`.

## Example Scenario
- Group `firewalls`: IPs `192.168.1.0/24`, API key `XXXX`, sourcetype `s_palo_5514`
- Group `local-logs`: IPs `127.0.0.1`, API key `YYYY`, sourcetype `s_syslog`

## Security Notice
- API keys are entered securely (not shown on screen).
- This script should be executed in a secure environment.

## Troubleshooting
- Ensure syslog-ng is running:
  ```bash
  systemctl status syslog-ng
  ```
- Check logs:
  ```bash
  tail -f /var/log/syslog
  ```

## License
MIT or as applicable to your organization's policy.

## Maintainers
Your team or organization contact details.

---
*Built for Ubuntu servers with ❤️ by PurpleOne GPT.*
