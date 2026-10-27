#!/usr/bin/env bash
# Points a Deployment manifest at a new image tag.
# usage: set-image.sh <backend|frontend> <sha-abc1234>
set -euo pipefail

APP="${1:?backend or frontend}"
TAG="${2:?tag such as sha-abc1234}"
FILE="k8s/${APP}/deployment.yaml"

sed -i -E "s|(image: ghcr.io/[^:]+-${APP}:).*|\1${TAG}|" "$FILE"
grep -n "image:" "$FILE"
