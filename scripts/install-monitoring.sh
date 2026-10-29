#!/usr/bin/env bash
# Installs Prometheus + Grafana (kube-prometheus-stack) on the k3s node, then loads the
# backend ServiceMonitor and the Grafana dashboard from the repo. Safe to run repeatedly.
# Runs on the node from the repo root. Called by scripts/deploy.sh.
#   UPGRADE=1 bash scripts/install-monitoring.sh    re-applies monitoring/values.yaml
set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export PATH="$PATH:/usr/local/bin"
NS=monitoring
RELEASE=monitoring
CHART_VERSION="${CHART_VERSION:-}"   # pin once you know the version that works for you

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

if ! kubectl -n "$NS" get secret grafana-admin >/dev/null 2>&1; then
  echo "==> Creating the Grafana admin secret (random password)"
  kubectl -n "$NS" create secret generic grafana-admin \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="$(openssl rand -base64 18)"
fi

if ! helm -n "$NS" status "$RELEASE" >/dev/null 2>&1 || [ "${UPGRADE:-0}" = "1" ]; then
  echo "==> Installing kube-prometheus-stack (first install takes 2-3 minutes)"
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update prometheus-community >/dev/null
  helm upgrade --install "$RELEASE" prometheus-community/kube-prometheus-stack \
    -n "$NS" -f monitoring/values.yaml \
    ${CHART_VERSION:+--version "$CHART_VERSION"} \
    --wait --timeout 10m
  helm -n "$NS" list
else
  echo "==> kube-prometheus-stack already installed (UPGRADE=1 to re-apply values)"
fi

echo "==> Backend ServiceMonitor"
kubectl apply -f monitoring/servicemonitor.yaml

echo "==> Grafana dashboard"
kubectl -n "$NS" create configmap zuri-dashboard \
  --from-file=zuri-overview.json=monitoring/dashboards/zuri-overview.json \
  --dry-run=client -o yaml \
  | kubectl label --local -f - grafana_dashboard=1 -o yaml \
  | kubectl apply -f -
