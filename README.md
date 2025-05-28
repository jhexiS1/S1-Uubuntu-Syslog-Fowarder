# SentinelOne Syslog-NG Multi-Source Setup (Ubuntu)

## Overview
This script installs and configures **syslog-ng OSE** on Ubuntu (20.04+),  
allowing you to forward logs from multiple source groups—each on its own UDP port—  
to a SentinelOne HTTP ingestion endpoint.

## Prerequisites
- Ubuntu **20.04** or **22.04**  
- **Root** (sudo) access  
- Internet access for repository and package installs  

## Installation

```bash
git clone https://github.com/jhexiS1/S1-Uubuntu-Syslog-Fowarder.git
cd S1-Uubuntu-Syslog-Fowarder
chmod +x sentinelone_syslog_ng_multi_source_setup.sh
sudo ./sentinelone_syslog_ng_multi_source_setup.sh
```

### What You’ll Be Asked
1. **Ingestion endpoint**: Full HTTP URL provided by SentinelOne.  
2. **Number of source groups**: Positive integer.  
3. For each group:  
   - **Name** (alphanumeric + underscores)  
   - **Unique UDP port** (1–65535)  
   - **IPs/CIDRs** (comma-separated; e.g. `10.0.0.0/8,192.168.1.0/24`)  
   - **SentinelOne API key**  
   - **Sourcetype/parser name**  

The script backs up any existing `/etc/syslog-ng/conf.d/sentinelone_multi_source.conf`.

## Firewall Configuration
- If **UFW** is installed, the script will open each user-selected UDP port **plus** TCP 5514 (console) automatically.  
- If **UFW** is not present, you must manually open those ports.

## Validation & Troubleshooting

- **Syntax check**  
  ```bash
  sudo syslog-ng --syntax-only
  ```
- **Restart/logs**  
  ```bash
  sudo systemctl restart syslog-ng
  sudo journalctl -u syslog-ng -f
  ```
- **Missing `mod-http` errors**  
  ```bash
  sudo apt-get install syslog-ng-mod-http
  ```

## Example Generated Snippet

```conf
@version: 3.36
@include "scl.conf"

filter f_webservers { or( netmask("10.0.1.0/24"); ); };

source s_webservers {
  syslog(ip(0.0.0.0) port(10514) transport("udp"));
};

destination d_webservers {
  http(
    url("https://ingest.sentinelone.net/http/1234")
    method("POST")
    headers(
      "Authorization: ApiKey ABCDEFG..."
      "Content-Type: application/json"
      "X-Sourcetype: webservers"
    )
    body("%MESSAGE%")
    tls(peer-verify(optional-trust))
  );
};

log { source(s_webservers); filter(f_webservers); destination(d_webservers); };
```

## Support
Open an Issue on GitHub or contact your internal operations/security team.

## License
MIT
