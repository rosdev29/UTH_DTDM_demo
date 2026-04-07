#!/usr/bin/env bash
set -e

URL="${1:-http://localhost:8080}"
RETRIES=3
SLEEP_SEC=2

for i in $(seq 1 $RETRIES); do
  if curl -fsS "$URL" > /dev/null; then
    echo "Health check passed at attempt $i"
    exit 0
  fi
  echo "Attempt $i failed, retrying..."
  sleep $SLEEP_SEC
done

echo "Health check failed after $RETRIES attempts"
exit 1
