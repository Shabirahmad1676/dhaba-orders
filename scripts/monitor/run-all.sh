#!/usr/bin/env bash
set -euo pipefail

WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
STATE_CM="monitor-state"
NS="ops"

post_alert() {
  local msg="$1"
  echo "[ALERT-BOT] $msg"
  if [ -n "$WEBHOOK_URL" ]; then
    curl -s -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"${msg}\"}" "$WEBHOOK_URL" >/dev/null || true
  fi
}

# Ensure state ConfigMap exists
kubectl get cm "$STATE_CM" -n "$NS" >/dev/null 2>&1 || \
  kubectl create cm "$STATE_CM" -n "$NS" --from-literal=last_status="OK" --from-literal=last_summary="0" >/dev/null

LAST_STATUS=$(kubectl get cm "$STATE_CM" -n "$NS" -o jsonpath='{.data.last_status}')
LAST_SUMMARY=$(kubectl get cm "$STATE_CM" -n "$NS" -o jsonpath='{.data.last_summary}')

ERR_OUTPUT=""
for SCRIPT in /app/scripts/monitor/check-cluster.sh /app/scripts/monitor/check-services.sh /app/scripts/monitor/check-databases.sh; do
  if ! OUT=$("$SCRIPT" 2>&1); then
    ERR_OUTPUT="${ERR_OUTPUT}${OUT}; "
  fi
done

NOW_EPOCH=$(date +%s)
CUR_STATUS="OK"
[ -n "$ERR_OUTPUT" ] && CUR_STATUS="FAIL"

if [ "$CUR_STATUS" = "FAIL" ] && [ "$LAST_STATUS" = "OK" ]; then
  post_alert "🚨 INCIDENT DETECTED: ${ERR_OUTPUT}"
elif [ "$CUR_STATUS" = "OK" ] && [ "$LAST_STATUS" = "FAIL" ]; then
  post_alert "✅ RECOVERED: All cluster, service, and database checks are green."
fi

# 30-minute (1800s) heartbeat summary when healthy
if [ "$CUR_STATUS" = "OK" ] && [ $((NOW_EPOCH - LAST_SUMMARY)) -ge 1800 ]; then
  post_alert "💚 All well: Dhaba staging & production clusters healthy."
  LAST_SUMMARY="$NOW_EPOCH"
fi

kubectl create cm "$STATE_CM" -n "$NS" \
  --from-literal=last_status="$CUR_STATUS" \
  --from-literal=last_summary="$LAST_SUMMARY" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
