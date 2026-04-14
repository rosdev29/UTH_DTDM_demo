#!/usr/bin/env bash
set -e

URL="${1:-http://localhost:8080}"
RETRIES=3
SLEEP_SEC=2
USE_NGINX_NETWORK="${USE_NGINX_NETWORK:-0}"

for i in $(seq 1 $RETRIES); do
  if { [ "$USE_NGINX_NETWORK" = "1" ] && docker compose exec -T nginx sh -c "wget -q -O /dev/null \"$URL\""; } || \
     { [ "$USE_NGINX_NETWORK" != "1" ] && curl -fsS "$URL" > /dev/null; }; then
    echo "Health check passed at attempt $i"
    exit 0
  fi
  echo "Attempt $i failed, retrying..."
  sleep $SLEEP_SEC
done

echo "Health check failed after $RETRIES attempts"
exit 1
