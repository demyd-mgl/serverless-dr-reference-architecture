#!/usr/bin/env bash
#
# failover-drill.sh
#
# Simulates a primary-region outage by disabling the primary Lambda
# (setting reserved concurrency to 0, which makes every invocation fail
# fast without deleting anything) and polls the failover DNS name /
# secondary endpoint until it starts responding, timing how long that
# takes. This is the "automated failover" half of the RTO measurement.
#
# Usage:
#   ./scripts/failover-drill.sh <primary-function-name> <endpoint-to-poll> <primary-region>
#
# Requires: aws-cli v2, configured credentials with lambda:PutFunctionConcurrency
# and lambda:DeleteFunctionConcurrency on the primary function.

set -euo pipefail

PRIMARY_FUNCTION_NAME="${1:?Usage: $0 <primary-function-name> <endpoint-to-poll> <primary-region>}"
POLL_ENDPOINT="${2:?endpoint-to-poll required, e.g. https://your-failover-dns-or-secondary-url}"
PRIMARY_REGION="${3:?primary-region required, e.g. us-east-1}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-2}"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-300}"

echo "== Serverless DR failover drill =="
echo "Primary function : ${PRIMARY_FUNCTION_NAME} (${PRIMARY_REGION})"
echo "Polling          : ${POLL_ENDPOINT}"
echo

echo "[1/3] Simulating primary outage (reserved concurrency -> 0)..."
aws lambda put-function-concurrency \
  --region "${PRIMARY_REGION}" \
  --function-name "${PRIMARY_FUNCTION_NAME}" \
  --reserved-concurrent-executions 0 >/dev/null

OUTAGE_START_EPOCH=$(date +%s)
echo "Outage injected at $(date -u -d "@${OUTAGE_START_EPOCH}" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -r "${OUTAGE_START_EPOCH}" +"%Y-%m-%dT%H:%M:%SZ")"
echo

echo "[2/3] Polling until the endpoint reports a healthy (non-primary-outage) response..."
elapsed=0
region_seen=""
until [[ "${region_seen}" != "" ]]; do
  response=$(curl -s -m 5 "${POLL_ENDPOINT}" || true)
  region_seen=$(echo "${response}" | grep -o '"region":[[:space:]]*"[^"]*"' | sed -E 's/.*"([^"]+)"$/\1/' || true)

  if [[ -n "${region_seen}" ]]; then
    break
  fi

  sleep "${POLL_INTERVAL_SECONDS}"
  elapsed=$(( $(date +%s) - OUTAGE_START_EPOCH ))
  if (( elapsed > MAX_WAIT_SECONDS )); then
    echo "Gave up after ${MAX_WAIT_SECONDS}s without a response. Check the health check / DNS config."
    exit 1
  fi
done

FAILOVER_DETECTED_EPOCH=$(date +%s)
OBSERVED_RTO=$(( FAILOVER_DETECTED_EPOCH - OUTAGE_START_EPOCH ))

echo "Endpoint responded from region: ${region_seen}"
echo "Observed RTO: ${OBSERVED_RTO} seconds"
echo

echo "[3/3] Restoring primary (removing the concurrency limit)..."
aws lambda delete-function-concurrency \
  --region "${PRIMARY_REGION}" \
  --function-name "${PRIMARY_FUNCTION_NAME}" >/dev/null

echo "Done. Record this run's RTO in README.md under 'Measured results'."
echo "Note: run this a handful of times - health-check timing has variance - and report a range, not a single sample."
