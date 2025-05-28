# SentinelOne Syslog-NG Multi-Source Setup (Ubuntu)

## Overview
Automates installation and configuration of syslog-ng on Ubuntu to forward logs 
from multiple source IP groups to SentinelOne’s HTTP ingestion endpoint.

## Default Ingestion URL
All destinations now point to:  
https://ingest.us1.sentinelone.net/services/collector/raw

## Prerequisites
- Ubuntu 20.04+ (tested on 20.04, 22.04)  
- syslog-ng ≥ 3.36  
- Root (or sudo) access  

## Installation

1. **Clone the repo**  
   ```bash
   git clone https://github.com/jhexiS1/S1-Uubuntu-Syslog-Fowarder.git
   cd S1-Uubuntu-Syslog-Fowarder
   ```

2. **Make the script executable**  
   ```bash
   chmod +x sentinelone_syslog_ng_multi_source_setup.sh
   ```

3. **Run the setup**  
   ```bash
   sudo ./sentinelone_syslog_ng_multi_source_setup.sh
   ```

## Configuration Prompts

- **Group name**: Alphanumeric + underscores only  
- **IP/CIDR list**: Comma-separated (e.g. `10.0.0.0/8,192.168.1.0/24`)  
- **API key**: SentinelOne ingestion key (kept hidden)  
- **Sourcetype**: Parser name or app identifier  

> The script will back up any existing `/etc/syslog-ng/conf.d/sentinelone_multi_source.conf`.

## Firewall

- **With UFW**: opens UDP 514 and TCP 5514 automatically  
- **Without UFW**: please open those ports manually in your firewall  

## Validation & Troubleshooting

- **Syntax check**  
  ```bash
  sudo syslog-ng --syntax-only
  ```
- **View live logs**  
  ```bash
  sudo journalctl -u syslog-ng -f
  ```
- **Missing HTTP module**  
  ```bash
  sudo apt install syslog-ng-mod-http
  ```

## Example Snippet

```conf
@version: 3.36
@include "scl.conf"

filter f_group1 {
  or(
    netmask("10.0.0.0/8");
    netmask("192.168.1.0/24");
  );
};

source s_group1 {
  syslog(ip(0.0.0.0) port(514) transport("udp"));
};

destination d_group1 {
  http(
    url("https://ingest.us1.sentinelone.net/services/collector/raw")
    method("POST")
    headers(
      "Authorization: ApiKey your_api_key"
      "Content-Type: application/json"
      "X-Sourcetype: group1"
    )
    body("%MESSAGE%")
    tls(peer-verify(optional-trust))
  );
};

log {
  source(s_group1);
  filter(f_group1);
  destination(d_group1);
};
```

## Support
Please open a GitHub Issue or contact your internal support team for questions.

## License
MIT
