#!/usr/bin/env bash
set -euo pipefail

echo "Installing k3s..."
curl -sfL https://get.k3s.io | sh -

echo "Waiting for node to become Ready..."
sleep 10

echo "Node status:"
sudo kubectl get nodes

echo "k3s installation complete."
echo "Kubeconfig is at /etc/rancher/k3s/k3s.yaml"