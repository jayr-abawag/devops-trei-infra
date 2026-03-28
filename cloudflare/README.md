# coffeecoding.co — K8s + Cloudflare Tunnel Setup

## Architecture

```text
Internet
   ↓
Cloudflare DNS (*.coffeecoding.co)
   ↓
Cloudflare Tunnel  [cloudflared — 2 replicas in `cloudflared` ns]
   ↓
ingress-nginx      [ClusterIP in `ingress-nginx` ns]
   ↓ routes by hostname
app (mc-pos)       → POS app    (pos.coffeecoding.co)
app2-service       → app2 pods  (app2.coffeecoding.co)
```

## Files

* `00-namespaces.yaml`: Creates `cloudflared`, `apps`, and `mc-pos` namespaces.
* `01-cloudflared.yaml`: ConfigMap + Deployment for cloudflared tunnel client.
* `02-ingress-nginx-install.yaml`: Instructions for installing ingress-nginx.
* `03-app1.yaml`: Ingress for POS host (`pos.coffeecoding.co` → `mc-pos/app`).
* `04-app2.yaml`: Deployment + Service + Ingress for app2.
* `deploy.sh`: Full automated deploy script.

## Prerequisites

* `kubectl` configured pointing to your Talos cluster
* `helm` installed
* `cloudflared` CLI installed locally
* Your tunnel credentials JSON file

## Setup Steps

### 1. Fill in your values

In `01-cloudflared.yaml`:

```YAML
tunnel: <YOUR_TUNNEL_ID>   # from: cloudflared tunnel list
```

In `04-app2.yaml`:

```YAML
image: your-registry/app2:latest   # your actual container image
containerPort: 8080                 # your app's port
```

In `03-app1.yaml`:

```YAML
host: pos.coffeecoding.co
service:
  name: app
namespace: mc-pos
```

> `03-app1.yaml` assumes service `app` already exists in namespace `mc-pos`.

### 2. Run the deploy script

```Shell
chmod +x deploy.sh
./deploy.sh
```

Or apply manually step by step:

```Shell
kubectl apply -f 00-namespaces.yaml

kubectl create secret generic cloudflared-credentials \
  --from-file=credentials.json=./tunnel-creds.json \
  -n cloudflared

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=ClusterIP

kubectl apply -f 01-cloudflared.yaml
kubectl apply -f 03-app1.yaml
kubectl apply -f 04-app2.yaml

cloudflared tunnel route dns <TUNNEL_NAME> pos.coffeecoding.co
cloudflared tunnel route dns <TUNNEL_NAME> app2.coffeecoding.co
```

### 3. Verify

```Shell
kubectl get pods -n cloudflared
kubectl get pods -n apps
kubectl get ingress -n mc-pos
kubectl get ingress -n apps

curl https://pos.coffeecoding.co
curl https://app2.coffeecoding.co
```

## Adding a New App

1. Copy `04-app2.yaml` → `05-app3.yaml`

2. Replace `app2` → `app3`, update image and port

3. Apply:

   ```Shell
   kubectl apply -f 05-app3.yaml
   cloudflared tunnel route dns <TUNNEL_NAME> app3.coffeecoding.co
   ```

4. **No changes needed** to cloudflared or ingress-nginx configs!

## Troubleshooting

```Shell
# Check cloudflared logs
kubectl logs -l app=cloudflared -n cloudflared --tail=50

# Check ingress-nginx logs
kubectl logs -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --tail=50

# Check ingress rules are registered
kubectl describe ingress -n mc-pos
kubectl describe ingress -n apps
```

<!-- end -->
