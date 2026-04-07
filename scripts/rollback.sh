#!/usr/bin/env bash
set -e

echo "Rollback: switch traffic to app-blue"

NGINX_CONF="./nginx/nginx.conf"

if [ ! -f "$NGINX_CONF" ]; then
  echo "nginx.conf not found at $NGINX_CONF"
  exit 1
fi

# Switch upstream back to blue
sed -i 's/# server app-blue:80;/server app-blue:80;/g' "$NGINX_CONF"
sed -i 's/server app-green:80;/# server app-green:80;/g' "$NGINX_CONF"

docker compose restart nginx

echo "Stopping app-green and ensuring app-blue is running"
docker compose up -d app-blue
docker compose stop app-green

echo "Rollback completed."
