#!/bin/bash

set -e 

if ! [ -x "$(command -v docker compose)" ]; then
  echo 'Error: docker compose is not installed.' >&2
  exit 1
fi

CERT_NAME="${CERT_NAME}"
DOMAIN_NAMES="${DOMAIN_NAMES}"
EMAIL="${EMAIL}"

if [ -z "${CERT_NAME}" ]; then
  echo 'Error: DOMAIN_NAMES environment variable is not set.' >&2
  exit 1
fi

if [ -z "${DOMAIN_NAMES}" ]; then
  echo 'Error: DOMAIN_NAMES environment variable is not set.' >&2
  exit 1
fi

if [ -z "${EMAIL}" ]; then
  echo 'Error: EMAIL environment variable is not set.' >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export COMPOSE_FILE="$SCRIPT_DIR/compose.yaml"

host_certbot_path="$SCRIPT_DIR/certbot"

if [ -d "$host_certbot_path" ]; then
  read -p "Existing data found for certificates. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

if [ ! -e "$host_certbot_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$host_certbot_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$host_certbot_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$host_certbot_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$host_certbot_path/conf/ssl-dhparams.pem"
  echo
fi

# Convert space-separated domains to array and build -d arguments
IFS=' ' read -ra DOMAINS <<< "$DOMAIN_NAMES"
DOMAIN_ARGS=""
for domain in "${DOMAINS[@]}"; do
  # Trim whitespace from domain name
  domain=$(echo "$domain" | xargs)
  DOMAIN_ARGS="$DOMAIN_ARGS -d $domain"
done

echo "Getting certificate for domains: ${DOMAIN_NAMES}..."
docker compose up --force-recreate -d nginx

sleep 3

docker compose run --rm certbot certonly \
    --webroot \
    --webroot-path /var/www/certbot \
    --email ${EMAIL} \
    --agree-tos \
    --no-eff-email \
    --cert-name ${CERT_NAME} \
    ${DOMAIN_ARGS}

docker compose down nginx
