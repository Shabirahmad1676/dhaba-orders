#!/usr/bin/env bash
set -euo pipefail

ISSUES=()

for NS in staging production; do
  # Postgres check
  if ! kubectl exec -n "$NS" postgres-0 -- pg_isready -U dhaba >/dev/null 2>&1; then
    ISSUES+=("${NS}/postgres-0 not accepting connections")
  else
    CONNS=$(kubectl exec -n "$NS" postgres-0 -- psql -U dhaba -d dhaba -tAc "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null || echo "0")
    DISK_PCT=$(kubectl exec -n "$NS" postgres-0 -- df -P /var/lib/postgresql/data | awk 'NR==2 {gsub(/%/,""); print $5}')
    if [ "${DISK_PCT:-0}" -gt 85 ]; then
      ISSUES+=("${NS}/postgres-0 volume ${DISK_PCT}% full (conns=${CONNS})")
    fi
  fi

  # Redis check
  PONG=$(kubectl exec -n "$NS" redis-0 -- redis-cli ping 2>/dev/null || echo "DOWN")
  if [ "$PONG" != "PONG" ]; then
    ISSUES+=("${NS}/redis-0 not responding")
  fi
done

if [ "${#ISSUES[@]}" -gt 0 ]; then
  printf '%s\n' "${ISSUES[@]}"
  exit 1
fi
echo "OK: Postgres and Redis healthy"
