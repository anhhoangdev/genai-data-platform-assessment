#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}
REGION=${REGION:-"us-central1"}
MIG_NAME=${MIG_NAME:-"ws-mig"}
BASTION_HOST=${BASTION_HOST:-"bastion.corp.internal"}
LOCAL_PORT=${LOCAL_PORT:-8888}

read WS_INSTANCE WS_ZONE < <("$(dirname "$0")/broker_select_vm.sh")
echo "Chosen workstation: $WS_INSTANCE in $WS_ZONE"

echo "Starting IAP tunnel to $WS_INSTANCE (JupyterLab)..."
gcloud compute ssh "ubuntu@${BASTION_HOST}" \
  --tunnel-through-iap \
  -- -N -L ${LOCAL_PORT}:127.0.0.1:8888 -J ubuntu@${BASTION_HOST} ubuntu@${WS_INSTANCE} &

echo "Open http://localhost:${LOCAL_PORT}"


