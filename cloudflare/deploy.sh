#!/bin/bash
# ============================================================
# coffeecoding.co — Full Deploy Script
# Run this after filling in your TUNNEL_ID and app images.
# ============================================================

set -e

TUNNEL_ID="<YOUR_TUNNEL_ID>"       # e.g. a1b2c3d4-xxxx-xxxx-xxxx-xxxxxxxxxxxx
TUNNEL_NAME="<YOUR_TUNNEL_NAME>"   # e.g. homelab-tunnel
CREDS_FILE="./tunnel-creds.json"   # path to your credentials JSON

echo "==> [1/6] Creating namespaces..."
kubectl apply -f 00-namespaces.yaml

echo "==> [2/6] Creating cloudflared credentials secret..."
kubectl create secret generic cloudflared-credentials \
  --from-file=credentials.json="$CREDS_FILE" \
  -n cloudflared \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> [3/6] Installing ingress-nginx (Helm)..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=ClusterIP \
  --wait

echo "==> [4/6] Deploying cloudflared..."
kubectl apply -f 01-cloudflared.yaml

echo "==> [5/6] Deploying apps..."
kubectl apply -f 03-app1.yaml
kubectl apply -f 04-app2.yaml

echo "==> [6/6] Registering DNS routes in Cloudflare..."
cloudflared tunnel route dns "$TUNNEL_NAME" pos.coffeecoding.co
cloudflared tunnel route dns "$TUNNEL_NAME" app2.coffeecoding.co

echo ""
echo "✅ Done! Verify with:"
echo "   kubectl get pods -n cloudflared"
echo "   kubectl get pods -n apps"
echo "   kubectl get ingress -n mc-pos"
echo "   kubectl get ingress -n apps"
echo ""
echo "   curl https://pos.coffeecoding.co"
echo "   curl https://app2.coffeecoding.co"
