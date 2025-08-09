#!/usr/bin/env bash
set -euo pipefail

# Select a workstation VM from the regional MIG (least-loaded placeholder -> random)

PROJECT_ID=${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}
REGION=${REGION:-"us-central1"}
MIG_NAME=${MIG_NAME:-"ws-mig"}

mapfile -t INSTANCES < <(gcloud compute instance-groups managed list-instances "$MIG_NAME" --region "$REGION" --format='value(instance,instanceStatus,instanceZone.basename())')

if [[ ${#INSTANCES[@]} -eq 0 ]]; then
  echo "No instances found in MIG $MIG_NAME" >&2
  exit 1
fi

IDX=$(( RANDOM % ${#INSTANCES[@]} ))
SELECTED=${INSTANCES[$IDX]}
NAME=$(awk '{print $1}' <<<"$SELECTED")
ZONE=$(awk '{print $3}' <<<"$SELECTED")
IP=$(gcloud compute instances describe "$NAME" --zone "$ZONE" --format='get(networkInterfaces[0].networkIP)')
echo "$NAME $ZONE $IP"


