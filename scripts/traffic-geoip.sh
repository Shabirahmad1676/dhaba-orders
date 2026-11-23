#!/usr/bin/env bash
set -euo pipefail

CITIES=(
  "Peshawar|Pakistan|34.0151|71.5249|39.42.10.14"
  "Islamabad|Pakistan|33.6844|73.0479|111.68.96.21"
  "Lahore|Pakistan|31.5204|74.3587|182.185.12.9"
  "Karachi|Pakistan|24.8607|67.0011|202.163.76.5"
  "Multan|Pakistan|30.1575|71.5249|119.155.44.8"
  "Dubai|United Arab Emirates|25.2048|55.2708|94.200.18.3"
  "London|United Kingdom|51.5072|-0.1276|86.142.33.19"
)
ENDPOINTS=("/api/menu|GET|200" "/api/orders|POST|201" "/api/orders|GET|200" "/api/stats|GET|200")

echo "Generating live traffic + GeoIP access logs for 20s..."
for _ in $(seq 1 40); do
  ENTRY="${CITIES[$((RANDOM % ${#CITIES[@]}))]}"
  IFS='|' read -r CITY COUNTRY LAT LON IP <<< "$ENTRY"
  EP="${ENDPOINTS[$((RANDOM % ${#ENDPOINTS[@]}))]}"
  IFS='|' read -r PATH_STR METHOD STATUS <<< "$EP"
  RT="0.0$((10 + RANDOM % 85))"
  TS_NS="$(date +%s)000000000"

  # Hit real production endpoint for Prometheus RED metrics
  if [ "$METHOD" = "POST" ]; then
    curl -s -o /dev/null -X POST http://dhaba.test/api/orders \
      -H "Content-Type: application/json" -d '{"item":"Chicken Karahi","quantity":1}' || true
  else
    curl -s -o /dev/null "http://dhaba.test${PATH_STR}" || true
  fi

  # Push GeoIP JSON access log entry to Loki
  LINE="{\"remote_addr\":\"${IP}\",\"geoip_city_name\":\"${CITY}\",\"geoip_country_name\":\"${COUNTRY}\",\"geoip_latitude\":${LAT},\"geoip_longitude\":${LON},\"method\":\"${METHOD}\",\"uri\":\"${PATH_STR}\",\"status\":${STATUS},\"request_time\":${RT}}"
  ESC_LINE=$(printf '%s' "$LINE" | sed 's/"/\\"/g')
  kubectl exec -n ops deploy/loki -- wget -qO- --header="Content-Type: application/json" \
    --post-data="{\"streams\":[{\"stream\":{\"job\":\"dhaba-access\",\"env\":\"production\"},\"values\":[[\"${TS_NS}\",\"${ESC_LINE}\"]]}]}" \
    http://localhost:3100/loki/api/v1/push >/dev/null 2>&1 || true
done
echo "Done! Refresh Grafana."
