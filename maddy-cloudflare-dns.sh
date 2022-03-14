#!/bin/sh
# 
# Update Cloudflare DNS entries for maddy installation
#   Uses `sed`
# 
# Copyright (c) Michael Nickerson 2022
# 
set -eu


# Definitions
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


# Get public IPs
[ -n "$IP4" ] || {
  for IPQ in ${IP_QUERY}; do
    IP4=$(curl -s -4 "$IPQ")
    [ -z "$IP4" ] || break
  done
}
[ "$IP4" = "skip" ] && IP4=

[ -n "$IP6" ] || {
   for IPQ in ${IP_QUERY}; do
    IP6=$(curl -s -6 "$IPQ")
    [ -z "$IP6" ] || break
  done
}
[ "$IP6" = "skip" ] && IP6=

[ -n "$IP4" ] || [ -n "$IP6" ] || {
  >&2 echo "maddy-cloudflare-dns: Unable to get public IP; aborting"
  exit 1
}


# Function to update or create record
#   dnsGetSetRecord <record> <name> <value>
dnsGetSetRecord() {
  REC=$1
  NAME=$2
  VAL=$3
  
  echo "ZONE='$ZONE'"
  echo "REC='$REC'"
  echo "NAME='$NAME'"
  echo "VAL='$VAL'"
  return 0
  # exit 1
  
  # Get any existing record
  CFR=$( curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records?type=${REC}&name=${NAME}" \
                 -H "Authorization: Bearer ${AUTH_KEY}" \
                 -H "Content-Type: application/json" )
  
  # Extract any existing ID and value
  ID=$(echo "$CFR" | sed -n 's/.*{"id":"\([a-z0-9]*\)".*/\1/p')
  CVAL=$(echo "$CFR" | sed -n 's/.*"type":"'"$REC"'".*"content":"\([^"]*\)".*/\1/p')
  
  # Continue if exists and is correct
  [ "$CVAL" = "$VAL" ] && return 0
  
  # Set update or create
  METHOD="PATCH"
  [ -z "$CVAL" ] && {
    METHOD="POST"
    TTL=",\"ttl\":1"
  }
  
  # Assemble update data
  DATA="{\"name\":\"$NAME\",\"type\":\"$REC\",\"content\":\"$VAL\"$TTL}"
  
  # Update or create record
  CFR=$( curl -s -X $METHOD "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records/$ID" \
                 -H "Authorization: Bearer ${AUTH_KEY}" \
                 -H "Content-Type: application/json" \
                 --data "$DATA" )
  
  # Check for success
  [ "${CFR#*\"success\":true}" = "$CFR" ] && {
    >&2 echo "cloudflare-ddns: Failed to update '$REC' name '$NAME'; response: '$CFR'"
    exit 1
  } || {
    echo "cloudflare-ddns: Updated '$REC' name '$NAME' to '$VAL'"
  }
}



# Set MX, $MAILHOST, DMARC, SPF, and DKIM for each domain
for D in ${DOMAINS}; do
  # Query zone ID
  CFR=$( curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${D}" \
                 -H "Authorization: Bearer ${AUTH_KEY}" \
                 -H "Content-Type: application/json" )
  
  ## Extract zone and verify exists
  ZONE=$(echo "$CFR" | sed -n 's/.*"id":"\([0-9a-z]*\)","name":"'"$D"'".*/\1/p')
  [ -n "$ZONE" ] || {
    >&2 echo "maddy-cloudflare-dns: No zone found for '$D'"
    exit 1
  }
  
  # MX record
  dnsGetSetRecord "MX" "$D" "$MAILHOST"
  
  # A and AAAA records for MX target
  [ -n "$IP4" ] && dnsGetSetRecord "A" "$MAILHOST" "$IP4"
  [ -n "$IP6" ] && dnsGetSetRecord "AAAA" "$MAILHOST" "$IP6"
  
  # DMARC
  [ -n "$DMARC" ] && dnsGetSetRecord "TXT" "_dmarc" "$DMARC"
  
  # SPF
  [ -n "$SPF" ] && dnsGetSetRecord "TXT" "$D" "$SPF"
  
  # DKIM
  DK=$(cat $DKIM/"${D}"_default.dns)
  [ -n "$DK" ] && dnsGetSetRecord "TXT" "default._domainkey.$D" "$DK"
done

# Exit with success
exit 0
