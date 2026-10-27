#!/usr/bin/env bash
# Runs ON the k3s node (sent by the CD workflow through SSM Run Command, no SSH),
# from a fresh checkout of the exact commit being deployed.
# usage: deploy.sh <image-tag> <env>      e.g. deploy.sh sha-95ab127 dev
set -euo pipefail

TAG="${1:?usage: deploy.sh <image-tag> <env>}"
ENV_NAME="${2:?usage: deploy.sh <image-tag> <env>}"
NS=zuri-market

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export PATH="$PATH:/usr/local/bin"
# shellcheck disable=SC1091
[ -f /etc/profile.d/aws.sh ] && . /etc/profile.d/aws.sh   # sets AWS_DEFAULT_REGION

echo "==> Waiting for k3s (a brand-new node can take a few minutes)"
for _ in $(seq 1 60); do
  kubectl get nodes 2>/dev/null | grep -q ' Ready' && break
  sleep 5
done
kubectl get nodes

echo "==> Setting image tags to ${TAG}"
for APP in backend frontend; do
  bash scripts/set-image.sh "$APP" "$TAG"
done

echo "==> Namespace and RBAC"
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/rbac.yaml

echo "==> Syncing secrets from AWS Secrets Manager (zuri/${ENV_NAME}/backend)"
bash scripts/sync-secrets.sh "$ENV_NAME"

echo "==> Server-side dry run of the application manifests"
kubectl apply --dry-run=server -f k8s/backend/ -f k8s/frontend/ -f k8s/ingress.yaml

echo "==> Applying application manifests"
kubectl apply -f k8s/backend/ -f k8s/frontend/ -f k8s/ingress.yaml

echo "==> Waiting for rollouts"
for APP in backend frontend; do
  if ! kubectl -n "$NS" rollout status "deployment/${APP}" --timeout=180s; then
    echo "!! ${APP} rollout failed, rolling back to the previous version"
    kubectl -n "$NS" describe pods -l "app=${APP}" | tail -n 30
    kubectl -n "$NS" rollout undo "deployment/${APP}"
    kubectl -n "$NS" rollout status "deployment/${APP}" --timeout=120s || true
    exit 1
  fi
done

if [ -f k8s/monitoring/servicemonitor.yaml ] \
  && kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
  echo "==> ServiceMonitor"
  kubectl apply -f k8s/monitoring/servicemonitor.yaml
fi

if [ -f scripts/health-check.sh ]; then
  echo "==> Installing the daily health check (idempotent)"
  mkdir -p /opt/zuri /var/log/zuri
  install -m 755 scripts/health-check.sh /opt/zuri/health-check.sh
  if [ ! -f /etc/cron.d/zuri-health ]; then
    echo '0 6 * * * root /opt/zuri/health-check.sh >> /var/log/zuri/cron.log 2>&1' > /etc/cron.d/zuri-health
  fi
fi

echo "==> Local check through the ingress"
curl -fsS http://localhost/api/health && echo

kubectl -n "$NS" get pods,svc,ingress
echo "==> Deployed ${TAG} to ${ENV_NAME}"
