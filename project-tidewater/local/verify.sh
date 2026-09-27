#!/usr/bin/env bash
# Same checks as the CI 'verify' job, runnable locally against the k3d
# cluster for fast iteration before pushing.
set -uo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
FAIL=0

echo "-- smoke: /healthz over 20 requests --"
OK=0
for i in $(seq 1 20); do
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$BASE_URL/healthz")
  [ "$code" = "200" ] && OK=$((OK+1))
done
echo "healthz success: $OK/20"
[ "$OK" -lt 19 ] && FAIL=1

echo "-- smoke: settlement create round-trip --"
resp=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 -X POST "$BASE_URL/settlements" \
  -H 'Content-Type: application/json' -d '{"merchant_id":1,"amount_cents":100}')
[ "$resp" != "201" ] && FAIL=1

echo "-- pod restart count --"
RESTARTS=$(kubectl get pods -l app=settle-api -o jsonpath='{.items[*].status.containerStatuses[0].restartCount}' | tr ' ' '\n' | awk '{s+=$1} END{print s+0}')
echo "restarts: $RESTARTS"
[ "$RESTARTS" -gt 0 ] && FAIL=1

if [ "$FAIL" -eq 0 ]; then
  echo "PASS"
  exit 0
else
  echo "FAIL"
  exit 1
fi
