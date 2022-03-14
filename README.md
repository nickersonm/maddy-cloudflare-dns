# maddy-cloudflare-dns
Update all relevant DNS records for a [new `maddy` installation](https://maddy.email/tutorials/setting-up/#dns-records), using [Cloudflare API](https://api.cloudflare.com/#dns-records-for-a-zone-list-dns-records)


## Description

POSIX shell script (also using `sed`); acquires current host's IP and updates specified Cloudflare DNS entries with the [Cloudflare API](https://api.cloudflare.com/#dns-records-for-a-zone-list-dns-records).


## Install

Clone this repository or just download [`maddy-cloudflare-dns.sh`](https://github.com/nickersonm/maddy-cloudflare-dns/raw/main/maddy-cloudflare-dns.sh) and configure.

Example:

```bash
wget https://raw.githubusercontent.com/nickersonm/maddy-cloudflare-dns/raw/main/maddy-cloudflare-dns.sh
nano maddy-cloudflare-dns.sh
```


## Configuration

Review and modify variable definitions in the **Definitions** section - minimal required changes are AUTH_KEY, DOMAINS, MAILHOST, and DMARC

```bash
## Account settings; items in <angled brackets> MUST be modified
AUTH_KEY="<apikey>"       # Relevant Cloudflare API key
DOMAINS="<domain1.tld> <myotherdomain.tld>" # Domains to modify
MAILHOST="<mail.domain1.tld>" # mail host's FQDN; if not this host specify IP below
DMARC="v=DMARC1; p=quarantine; ruf=mailto:dmarc@<domain1.tld>"  # Delete for no DMARC entry

## Standard settings, optionally modify
SPF="v=spf1 mx ~all"
DKIM=/var/lib/maddy/dkim_keys # Expect DKIM TXT entry in $DKIM/$DOMAIN_default.dns

## IP settings, optionally specify, skip with value "skip"
IP4=""
IP6=""
IP_QUERY="https://icanhazip.com https://api.ip.sb/ip https://api64.ipify.org https://ip.seeip.org/ https://api.my-ip.io/ip"
```


## Usage

Customize and run. If the mail server's IP changes regularly, use `cron`, `/etc/periodic/`, or similar to run frequently. For example:

```bash
sh maddy-cloudflare-dns.sh    # Run once

chmod 770 maddy-cloudflare-dns.sh         # Contains API key
doas mv maddy-cloudflare-dns.sh /etc/periodic/15min
doas chown root:root /etc/periodic/15min/maddy-cloudflare-dns.sh
```

Errors are output to `stderr`, information is output to `stdout`.

