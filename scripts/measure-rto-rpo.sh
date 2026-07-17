#!/usr/bin/env bash
#
# measure-rto-rpo.sh
#
# Measures actual DynamoDB Global Table replication lag (a proxy for RPO):
# writes a timestamped canary item via the primary region's Lambda Function
# URL, then polls the secondary region's Function URL until it can read
# that same item back, and reports the elapsed time.
#
# This does NOT simulate an outage - for the RTO side (DNS/health-check
# failover timing), run scripts/failover-drill.sh separately.
#
# Usage:
#   ./scripts/measure-rto-rpo.sh <primary-function-url> <secondary-function-url> [primary-health-check-id]
#
# Requires: curl. The health-check-id argument is optional and, if given,
# is just printed back so you can cross-reference it in the Route 53
# console while interpreting results.

set -euo pipefail

PRIMARY_URL="${1:?Usage: $0 <primary-function-url> <secondary-function-url> [primary-health-check-id]}"
SECONDARY_URL="${2:?secondary-function-url required}"
HEALTH_CHECK_ID="${3:-}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-1}"
MAX_WAIT_SECONDS="${MAX_WAIT_SECONDS:-120}"
SAMPLES="${SAMPLES:-5}"

echo "== Serverless DR replication-lag (RPO) measurement =="
echo "Primary   : ${PRIMARY_URL}"
echo "Secondary : ${SECONDARY_URL}"
[[ -n "${HEALTH_CHECK_ID}" ]] && echo "Health check ID: ${HEALTH_CHECK_ID}"
echo "Taking ${SAMPLES} samples..."
echo

total=0
for i in $(seq 1 "${SAMPLES}"); do
  write_response=$(curl -s -m 10 -X POST "${PRIMARY_URL}")
  canary_id=$(echo "${write_response}" | grep -o '"canary_id":[[:space:]]*"[^"]*"' | sed -E 's/.*"([^"]+)"$/\1/')
  write_epoch=$(date +%s.%N)

  if [[ -z "${canary_id}" ]]; then
    echo "  sample ${i}: write failed, response was: ${write_response}"
    continue
  fi

  elapsed=0
  found=""
  while [[ -z "${found}" ]]; do
    read_response=$(curl -s -m 10 "${SECONDARY_URL}?canary_id=${canary_id}" || true)
    found=$(echo "${read_response}" | grep -o '"found":[[:space:]]*true' || true)
    if [[ -n "${found}" ]]; then
      break
    fi
    sleep "${POLL_INTERVAL_SECONDS}"
    elapsed=$(echo "$(date +%s.%N) - ${write_epoch}" | bc)
    if (( $(echo "${elapsed} > ${MAX_WAIT_SECONDS}" | bc -l) )); then
      echo "  sample ${i}: not replicated within ${MAX_WAIT_SECONDS}s"
      break
    fi
  done

  if [[ -n "${found}" ]]; then
    lag=$(echo "$(date +%s.%N) - ${write_epoch}" | bc)
    printf "  sample %d: replicated in %.2fs (canary_id=%s)\n" "${i}" "${lag}" "${canary_id}"
    total=$(echo "${total} + ${lag}" | bc)
  fi
done

echo
if (( $(echo "${total} > 0" | bc -l) )); then
  avg=$(echo "${total} / ${SAMPLES}" | bc -l)
  printf "Average replication lag across %d samples: %.2fs\n" "${SAMPLES}" "${avg}"
fi
echo "Record these numbers in README.md under 'Measured results' with the date, region pair, and account tier they came from."
