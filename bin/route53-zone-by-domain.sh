#!/bin/bash

# Verify Route53 zone is unique then print Hosted Zone Id if exist
# Exit with error if not unique
# This won't work very well for a mix of public and private zones

AWS="${AWS:-aws}"
JQ="${JQ:-jq}"
DOMAIN="$1"
PRIVATE_ZONE="${2:-false}"

if test -z "$DOMAIN"; then echo "Usage: $0 <domain.name>"; exit 1; fi

if test -n "$EXTERNAL_AWS_ACCESS_KEY" -a -n "$EXTERNAL_AWS_SECRET_KEY"; then
  unset AWS_SESSION_TOKEN
  export AWS_DEFAULT_REGION=us-east-1
  export AWS_ACCESS_KEY_ID=$EXTERNAL_AWS_ACCESS_KEY
  export AWS_SECRET_ACCESS_KEY=$EXTERNAL_AWS_SECRET_KEY
fi

route53_zones_resp=$($AWS --output=json route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --max-items=2)
# TODO what happens if there are two+ (private) zones?
zone=$($JQ ".HostedZones[] | select(.Config.PrivateZone == $PRIVATE_ZONE)" <<< $route53_zones_resp)
test -z "$zone" -o "$zone" = "null" && exit 0

name=$($JQ -r "select(.Name == \"${DOMAIN}.\") | .Name" <<< $zone)
test "$DOMAIN" != "$name" -a "${DOMAIN}." != "$name" && exit 0

next_dns_name=$($JQ -r .NextDNSName <<< $route53_zones_resp)
if test "$name" = "$next_dns_name"; then
    echo "$name zone is not unique in Route53"
    exit 1
fi

id=$($JQ -r "select(.Name == \"${DOMAIN}.\") | .Id" <<< $zone | sed -e 's|/hostedzone/||')
echo $id
