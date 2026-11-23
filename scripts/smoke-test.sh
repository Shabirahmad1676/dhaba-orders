#!/usr/bin/env bash
set -euo pipefail

URL="${1:-http://staging.dhaba.test}"

echo "Running smoke tests against ${URL}..."
curl -sf "${URL}/health" >/dev/null
curl -sf "${URL}/api/menu" | grep -q "Chicken Karahi"

ORDER_RES=$(curl -sf -X POST "${URL}/api/orders" \
  -H "Content-Type: application/json" \
  -d '{"item":"Chicken Karahi","quantity":1}')
echo "$ORDER_RES" | grep -q '"status":"new"'

sleep 3
curl -sf "${URL}/api/stats" | grep -q "orders_per_minute"
echo "Smoke tests PASSED for ${URL}"
