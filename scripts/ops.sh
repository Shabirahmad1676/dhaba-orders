#!/usr/bin/env bash
set -euo pipefail

CMD="${1:-help}"
ARG2="${2:-staging}"
ARG3="${3:-staging}"

case "$CMD" in
  status)
    for NS in staging production; do
      echo "=== $NS ==="
      kubectl get pods,pvc,ingress -n "$NS"
    done
    ;;
  db)
    for NS in staging production; do
      echo "=== $NS Databases ==="
      kubectl exec -n "$NS" postgres-0 -- psql -U dhaba -d dhaba -c \
        "SELECT count(*) AS total_orders, pg_size_pretty(pg_database_size('dhaba')) AS db_size FROM orders;"
      kubectl exec -n "$NS" redis-0 -- redis-cli INFO memory | grep -E "used_memory_human|maxmemory_human"
      echo "Queue length: $(kubectl exec -n "$NS" redis-0 -- redis-cli LLEN orders_queue)"
    done
    ;;
  logs)
    kubectl logs -n "$ARG3" "deploy/${ARG2}" --tail=50 -f
    ;;
  load)
    URL="http://staging.dhaba.test"
    [ "$ARG3" = "production" ] && URL="http://dhaba.test"
    ./scripts/load.sh "$URL" "$ARG2"
    ;;
  *)
    echo "Usage: $0 {status|db|logs <service> [ns]|load <seconds> [staging|production]}"
    exit 1
    ;;
esac
