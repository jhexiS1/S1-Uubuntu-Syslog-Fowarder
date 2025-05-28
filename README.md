# SentinelOne Syslog-NG Multi-Source Setup (Ubuntu)

## Overview
Automates installation and configuration of syslog-ng on Ubuntu to forward logs 
from multiple source IP groups to a SentinelOne HTTP ingestion endpoint.

## Prerequisites
- Ubuntu 20.04+  
- syslog-ng ≥ 3.36  
- Root (sudo) access  

## Installation

```bash
git clone https://github.com/jhexiS1/S1-Uubuntu-Syslog-Fowarder.git
cd S1-Uubuntu-Syslog-Fowarder
chmod +x sentinelone_syslog_ng_multi_source_setup.sh
sudo ./sentinelone_syslog_ng_multi_source_setup.sh
```

The script will prompt you for:
- **Ingestion endpoint** (full HTTP URL)  
- **Number of source groups**  
- **Group names**  
- **IPs/CIDRs**  
- **SentinelOne API keys**  
- **Sourcetype/parser names**

It backs up any existing `/etc/syslog-ng/conf.d/sentinelone_multi_source.conf`.

## Firewall
- With UFW: opens UDP 514 and TCP 5514 automatically  
- Without UFW: open these ports manually  

## Validation & Troubleshooting

- **Syntax check**  
  ```bash
  sudo syslog-ng --syntax-only
  ```
- **Live logs**  
  ```bash
  sudo journalctl -u syslog-ng -f
  ```
- **Install HTTP module**  
  ```bash
  sudo apt install syslog-ng-mod-http
  ```

## Example Snippet

```conf
@version: 3.36
@include "scl.conf"

filter f_example {
  or(
    netmask("10.0.0.0/8");
    netmask("192.168.1.0/24");
  );
};

source s_example {
  syslog(ip(0.0.0.0) port(514) transport("udp"));
};

destination d_example {
    http(
        url("${ingest_endpoint}")
        method("POST")
        headers(
            "Authorization: ApiKey ${api_key}"
            "Content-Type: application/json"
            "X-Sourcetype: example"
        )
        body("%MESSAGE%")
        tls(peer-verify(optional-trust))
    );
};

log {
    source(s_example);
    filter(f_example);
    destination(d_example);
};
```

## Support
Open a GitHub issue for questions.

## License
MIT
