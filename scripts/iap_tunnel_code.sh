#!/usr/bin/env bash
set -euo pipefail
: "${PROJECT:?PROJECT is required}"
: "${BASTION_ZONE:?BASTION_ZONE is required}"
BASTION="${BASTION:-bastion.corp.internal}"
WORKSTATION_LABEL="${WORKSTATION_LABEL:-primary}"
LOCAL_PORT="${LOCAL_PORT:-8080}"
REMOTE_PORT="${REMOTE_PORT:-8080}"
USER_NAME="${USER_NAME:-$USER}"

# 1) Start IAP tunnel to bastion SSH on localhost:9222
gcloud compute start-iap-tunnel "${BASTION}" 22 \
  --local-host-port=127.0.0.1:9222 \
  --zone="${BASTION_ZONE}" \
  --project="${PROJECT}" >/dev/null &
TUN_PID=$!
sleep 2

cleanup() { kill "${TUN_PID}" 2>/dev/null || true; }
trap cleanup EXIT

# 2) Pick a deterministic workstation by label
WS_HOST=$(gcloud compute instances list \
  --filter="labels.role=workstation AND labels.profile=${WORKSTATION_LABEL}" \
  --format="value(name)" --project="${PROJECT}" | sort | head -n1)

if [[ -z "${WS_HOST}" ]]; then
  echo "No workstation found with profile=${WORKSTATION_LABEL}" >&2
  exit 1
fi

# 3) Forward local port to target service on the workstation
ssh -o "ProxyCommand=nc -x 127.0.0.1:9222 %h %p" \
    -J "${USER_NAME}@${BASTION}" "${USER_NAME}@${WS_HOST}" \
    -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}" -N


