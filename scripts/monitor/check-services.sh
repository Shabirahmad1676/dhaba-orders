#!/usr/bin/env bash
set -euo pipefail

ISSUES=()

for NS in staging production; do
  for SVC in web menu-api orders-api stats-api; do
    if ! curl -sf -m 3 "http://${SVC}.${NS}.svc.cluster.local/health" >/dev/null 2>&1; then
      ISSUES+=("${NS}/${SVC} health endpoint unreachable")
    fi
  done

  # Check kitchen-worker heartbeat and queue length in Redis
  HB=$(kubectl exec -n "$NS" redis-0 -- redis-cli EXISTS worker:heartbeat 2>/dev/null || echo "0")
  [ "$HB" != "1" ] && ISSUES+=("${NS}/kitchen-worker heartbeat missing in Redis")

  QLEN=$(kubectl exec -n "$NS" redis-0 -- redis-cli LLEN orders_queue 2>/dev/null || echo "0")
  if [ "${QLEN:-0}" -gt 20 ]; then
    ISSUES+=("${NS} orders_queue backlog growing (len=${QLEN})")
  fi
done

if [ "${#ISSUES[@]}" -gt 0 ]; then
  printf '%s\n' "${ISSUES[@]}"
  exit 1
fi
echo "OK: all services & queues healthy"
