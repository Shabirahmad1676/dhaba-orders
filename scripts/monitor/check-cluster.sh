#!/usr/bin/env bash
set -euo pipefail

ISSUES=()

# Check NotReady nodes
NOT_READY=$(kubectl get nodes --no-headers | awk '$2 != "Ready" {print $1":"$2}')
[ -n "$NOT_READY" ] && ISSUES+=("Nodes not Ready: $NOT_READY")

# Check crashing, ImagePullBackOff, or high-restart (>5) pods across staging/production/ops
BAD_PODS=$(kubectl get pods -A --no-headers | awk '$1 ~ /^(staging|production|ops)$/ && ($4 ~ /CrashLoopBackOff|ImagePullBackOff|ErrImagePull|Error/ || $5 > 5) {print $1"/"$2"("$4",restarts="$5")"}')
[ -n "$BAD_PODS" ] && ISSUES+=("Unhealthy pods: $BAD_PODS")

# Check node CPU/Memory usage if metrics-server is ready
if kubectl top nodes --no-headers >/dev/null 2>&1; then
  HIGH_RES=$(kubectl top nodes --no-headers | awk '{gsub(/%/,""); if ($3 > 85 || $5 > 85) print $1"(CPU:"$3"%,MEM:"$5"%)"}')
  [ -n "$HIGH_RES" ] && ISSUES+=("High node resource usage: $HIGH_RES")
fi

# Check recent Warning events in staging/production
WARNINGS=$(kubectl get events -A --field-selector type=Warning --no-headers 2>/dev/null | awk '$1 ~ /^(staging|production)$/ {print $1"/"$4":"$6}' | tail -n 3)
[ -n "$WARNINGS" ] && ISSUES+=("Recent warnings: $WARNINGS")

if [ "${#ISSUES[@]}" -gt 0 ]; then
  printf '%s\n' "${ISSUES[@]}"
  exit 1
fi
echo "OK: cluster healthy"
