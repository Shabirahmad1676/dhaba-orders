#!/usr/bin/env bash
set -euo pipefail

SHA=$(git rev-parse --short HEAD)
CHANGED=$(git diff-tree --no-commit-id --name-only -r HEAD)

for SVC in web menu-api orders-api kitchen-worker stats-api; do
  if echo "$CHANGED" | grep -q "^${SVC}/"; then
    echo "==> Deploying ${SVC}:${SHA} to staging & production..."
    docker build --build-arg GIT_SHA="$SHA" -t "${SVC}:${SHA}" "$SVC"
    for node in k3d-dhaba-server-0 k3d-dhaba-agent-0 k3d-dhaba-agent-1; do
      docker save "${SVC}:${SHA}" | docker exec -i "$node" ctr -n k8s.io images import - >/dev/null
    done
    kubectl set image "deployment/${SVC}" "${SVC}=${SVC}:${SHA}" -n staging
    kubectl set image "deployment/${SVC}" "${SVC}=${SVC}:${SHA}" -n production
    kubectl rollout status "deployment/${SVC}" -n staging --timeout=60s
    kubectl rollout status "deployment/${SVC}" -n production --timeout=60s
  fi
done
