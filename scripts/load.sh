#!/usr/bin/env bash
set -euo pipefail

URL="${1:-http://staging.dhaba.test}"
DURATION="${2:-10}"

if ! [[ "$DURATION" =~ ^[0-9]+$ ]] || [ "$DURATION" -le 0 ]; then
  echo "Usage: $0 <base-url> <duration-seconds>" >&2
  exit 1
fi

END_TIME=$((SECONDS + DURATION))
SUCCESS=0
FAILED=0

echo "Sending orders to ${URL}/api/orders for ${DURATION}s..."
while [ "$SECONDS" -lt "$END_TIME" ]; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 3 \
    -X POST "${URL}/api/orders" \
    -H "Content-Type: application/json" \
    -d '{"item":"Chicken Karahi","quantity":1}' || echo "000")

  if [ "$CODE" = "201" ] || [ "$CODE" = "200" ]; then
    SUCCESS=$((SUCCESS + 1))
  else
    FAILED=$((FAILED + 1))
  fi
  sleep 0.2
done

echo "Load test finished: ${SUCCESS} succeeded, ${FAILED} failed"
[ "$FAILED" -eq 0 ]
