#!/usr/bin/env bash
set -e

echo "Deploy: start app-green"
docker compose up -d app-green

echo "Run health check for app-green directly"
USE_NGINX_NETWORK=1 bash ./scripts/health-check.sh http://app-green:80

echo "Health check passed. Switch traffic to app-green"
NGINX_CONF="./nginx/nginx.conf"

if [ ! -f "$NGINX_CONF" ]; then
  echo "nginx.conf not found at $NGINX_CONF"
  exit 1
fi

sed -i 's/# server app-blue:80;/server app-blue:80;/g' "$NGINX_CONF" >/dev/null 2>&1 || true
sed -i 's/server app-blue:80;/# server app-blue:80;/g' "$NGINX_CONF"
sed -i 's/# server app-green:80;/server app-green:80;/g' "$NGINX_CONF" >/dev/null 2>&1 || true

docker compose restart nginx

echo "Stop app-blue after switch"
docker compose stop app-blue

echo "Deploy completed successfully."
