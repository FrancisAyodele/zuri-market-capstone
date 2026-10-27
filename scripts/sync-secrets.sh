#!/usr/bin/env bash
# Turns the AWS Secrets Manager secret zuri/<env>/backend into the Kubernetes Secret
# "backend-secrets". Runs on the node, which reads the secret with its IAM role.
# usage: sync-secrets.sh <dev|prod>
set -euo pipefail

ENV_NAME="${1:?usage: sync-secrets.sh <dev|prod>}"
NS=zuri-market
TMP="$(mktemp)"
trap 'shred -u "$TMP" 2>/dev/null || rm -f "$TMP"' EXIT

aws secretsmanager get-secret-value --secret-id "zuri/${ENV_NAME}/backend" \
  --query SecretString --output text \
  | jq -r 'to_entries[] | "\(.key)=\(.value)"' > "$TMP"

if ! grep -q '^API_SECRET_KEY=' "$TMP"; then
  echo "zuri/${ENV_NAME}/backend has no API_SECRET_KEY (the name server.js reads)" >&2
  exit 1
fi

kubectl -n "$NS" create secret generic backend-secrets \
  --from-env-file="$TMP" --dry-run=client -o yaml | kubectl apply -f -
