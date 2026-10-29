#!/usr/bin/env bash
# Sends real traffic, including some failures, so the dashboard shows data.
# usage: generate-traffic.sh <node-public-ip> [rounds]
set -euo pipefail

HOST="${1:?usage: generate-traffic.sh <node-public-ip> [rounds]}"
ROUNDS="${2:-300}"
BASE="http://${HOST}"

for i in $(seq 1 "$ROUNDS"); do
  curl -s -o /dev/null "$BASE/api/products"
  curl -s -o /dev/null "$BASE/api/products?category=tech"
  curl -s -o /dev/null "$BASE/api/products/$(( (i % 8) + 1 ))"
  curl -s -o /dev/null "$BASE/api/store"
  curl -s -o /dev/null "$BASE/api/products/999999"
  curl -s -o /dev/null -X POST -H "Content-Type: application/json" -d '{"items":[]}' "$BASE/api/cart/validate"
  sleep 0.2
  [ $((i % 50)) -eq 0 ] && echo "$i/$ROUNDS rounds sent"
done
echo "Done: $((ROUNDS * 6)) requests (about a third return 404 or 401)"
