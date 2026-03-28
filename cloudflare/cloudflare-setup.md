# Cloudflare Tunnel + Ingress-Nginx Setup — What Actually Worked

Step-by-step record of the exact setup performed to route
`pos.coffeecoding.co` through a Cloudflare Tunnel to a Next.js POS app
running inside a Talos Kubernetes cluster.

## Architecture

```text
Browser
  ↓
Cloudflare (CNAME pos.coffeecoding.co → bc6ecd05.cfargotunnel.com)
  ↓
Tunnel: talos-home-lab (bc6ecd05-e5eb-4ba0-83ed-8f9e23d47dfb)
  ↓  (2 cloudflared connectors, HA)
ingress-nginx  (ClusterIP, in-cluster only)
  ↓  (host-based routing)
Service: app (mc-pos) → pos-frontend pods :3000
```

---

## Prerequisites

- `kubectl` access to the Talos cluster (via kubeconfig in workspace root)
- `helm` installed locally
- `cloudflared` CLI installed locally
- A Cloudflare account with a Tunnel already created

---

## Step 1 — Create namespaces

```bash
kubectl apply -f 00-namespaces.yaml
```

This creates three namespaces:

- `cloudflared` — runs the tunnel client
- `apps` — general workloads
- `mc-pos` — POS application workloads

> If `mc-pos` already exists the apply is a no-op; safe to re-run.

---

## Step 2 — Install ingress-nginx via Helm

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=ClusterIP \
  --wait
```

**Important:** Use `type=ClusterIP` only. Do **not** add
`--set controller.service.externalTrafficPolicy=Local` — that flag is
only valid on LoadBalancer/NodePort services and will cause the install
to fail with a validation error.

Verify:

```bash
kubectl get pods -n ingress-nginx
kubectl get ingressclass
# Expected: ingressclass "nginx" listed
```

---

## Step 3 — Set up cloudflared credentials

### 3a. Rotate the local cert to the correct Cloudflare account

The local `~/.cloudflared/cert.pem` must contain an Argo Tunnel Token
that encodes the **zone ID**, **account ID**, and **API token** for the
target Cloudflare account.

Build the cert payload and write it:

```powershell
$payload = @{
  zoneID    = '<YOUR_ZONE_ID>'
  accountID = '<YOUR_ACCOUNT_ID>'
  apiToken  = '<YOUR_API_TOKEN>'
} | ConvertTo-Json -Compress

$b64  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))
$cert = "-----BEGIN ARGO TUNNEL TOKEN-----`n" +
        (($b64 -split '(.{1,64})' | Where-Object { $_ -ne '' }) -join "`n") +
        "`n-----END ARGO TUNNEL TOKEN-----"

$cert | Set-Content -Path "$HOME\.cloudflared\cert.pem" -Encoding ascii
```

Verify (confirms correct zone without exposing full token):

```powershell
python -c "
import base64,json,pathlib
p=pathlib.Path.home()/'.cloudflared'/'cert.pem'
s=p.read_text()
b=''.join([l.strip() for l in s.splitlines() if 'BEGIN' not in l and 'END' not in l and l.strip()])
d=json.loads(base64.b64decode(b).decode())
print(d.get('zoneID'), d.get('accountID'))
"
```

### 3b. List available tunnels under the new account

```bash
cloudflared tunnel list
# Note the tunnel ID and name for the tunnel pointing at your cluster
```

For this setup, `talos-home-lab` (UUID `bc6ecd05-e5eb-4ba0-83ed-8f9e23d47dfb`) was used.

### 3c. Generate tunnel credentials file

```bash
cloudflared tunnel token \
  --cred-file ./tunnel-creds.json \
  bc6ecd05-e5eb-4ba0-83ed-8f9e23d47dfb
```

### 3d. Load credentials into Kubernetes

```bash
kubectl create secret generic cloudflared-credentials \
  --from-file=credentials.json=./tunnel-creds.json \
  -n cloudflared \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## Step 4 — Deploy cloudflared to the cluster

`01-cloudflared.yaml` contains a ConfigMap with the tunnel routing rules
and a 2-replica Deployment for HA.

**Make sure the tunnel ID in the ConfigMap matches your actual tunnel:**

```yaml
# 01-cloudflared.yaml → data.config.yaml
tunnel: bc6ecd05-e5eb-4ba0-83ed-8f9e23d47dfb  # ← must match cloudflared tunnel list
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: "*.coffeecoding.co"
    service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
  - service: http_status:404
```

Apply and verify:

```bash
kubectl apply -f 01-cloudflared.yaml
kubectl rollout status deploy/cloudflared -n cloudflared
kubectl get pods -n cloudflared          # Expect 2/2 Running
cloudflared tunnel info <TUNNEL_UUID>    # Expect active connector(s)
```

If the pods are `Running` but the connector count is 0, check logs:

```bash
kubectl logs -n cloudflared -l app=cloudflared --tail=60
```

Common cause: tunnel ID in ConfigMap does not match the credentials JSON.

---

## Step 5 — Register the DNS route

```bash
cloudflared tunnel route dns --overwrite-dns \
  bc6ecd05-e5eb-4ba0-83ed-8f9e23d47dfb \
  pos.coffeecoding.co
```

> Use the **tunnel UUID**, not the name — the name lookup can silently
> resolve to a tunnel in a different account and create the CNAME in the
> wrong zone.

Verify the record was created in the correct zone (requires API access):

```powershell
$token  = '<YOUR_API_TOKEN>'
$zone   = '<YOUR_ZONE_ID>'
$h      = @{ Authorization="Bearer $token"; 'Content-Type'='application/json' }
$r      = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$zone/dns_records?name=pos.coffeecoding.co" -Headers $h
$r.result | Select-Object name, type, content
# Expected: CNAME → bc6ecd05-e5eb-4ba0-83ed-8f9e23d47dfb.cfargotunnel.com
```

Then verify public resolution:

```bash
nslookup pos.coffeecoding.co 1.1.1.1
# Expected: resolves to Cloudflare anycast IPs (104.21.x.x / 172.67.x.x)
```

---

## Step 6 — Deploy POS ingress and backend service

`03-app1.yaml` contains:

1. A ClusterIP `Service` named `app` in `mc-pos` that maps port `80`
   → pod port `3000` via selector `app: pos-frontend`.
2. An `Ingress` that routes `pos.coffeecoding.co /` → `app:80`.

```bash
kubectl apply -f 03-app1.yaml
kubectl get svc app -n mc-pos          # Expect ClusterIP
kubectl get endpoints app -n mc-pos    # Expect populated pod IPs
kubectl get ingress -n mc-pos          # Expect ADDRESS filled by ingress-nginx
```

> **Why a separate `app` service?** The existing `pos-frontend` service
> is exposed on port `3000` as NodePort; the Ingress backend needs a
> ClusterIP on port `80`. The `app` service acts as a thin alias so the
> Ingress and the existing workload stay decoupled.

---

## Step 7 — End-to-end verification

```bash
curl -I https://pos.coffeecoding.co
# Expected: HTTP/1.1 200 OK, Server: cloudflare
```

Full stack check:

```bash
kubectl get pods -n cloudflared        # 2/2 Running
kubectl get pods -n ingress-nginx      # 1/1 Running
kubectl get svc app endpoints -n mc-pos
kubectl describe ingress pos-ingress -n mc-pos
cloudflared tunnel info bc6ecd05-e5eb-4ba0-83ed-8f9e23d47dfb
# CONNECTOR list should show at least 1 active entry
```

---

## Troubleshooting reference

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `DNS CNAME in wrong zone` | cert.pem encoded old account | Rotate cert.pem (Step 3a) and re-run Step 5 |
| `Tunnel: no active connection` | Wrong tunnel ID in ConfigMap | Match ID in `01-cloudflared.yaml` to `cloudflared tunnel list` |
| `503 Service Unavailable` | Ingress backend service missing or no endpoints | Check `kubectl get endpoints app -n mc-pos`; verify app service selector matches pods |
| `Helm install fails: externalTrafficPolicy` | Flag set on ClusterIP service | Remove `--set controller.service.externalTrafficPolicy=Local` |
| `cloudflared tunnel route dns` prints jayrlabs.codes | cert.pem still has old zone ID | Re-rotate cert.pem to new account credentials |
| `cert.pem invalid value` | Base64 padding or JSON encoding error | Re-generate using the PowerShell snippet in Step 3a |

---

## Files changed in this session

| File | Change |
| --- | --- |
| `00-namespaces.yaml` | Added `mc-pos` namespace |
| `01-cloudflared.yaml` | Updated tunnel ID to `bc6ecd05` |
| `02-ingress-nginx-install.yaml` | Removed invalid `externalTrafficPolicy=Local` flag |
| `03-app1.yaml` | Replaced app1 template with POS ingress + `app` service alias |
| `deploy.sh` | Updated DNS route target and verify commands to `mc-pos` |
| `README.md` | Updated architecture, file table, and manual commands |
| `~/.cloudflared/cert.pem` | Rotated to new Cloudflare account credentials |
| `tunnel-creds.json` | Generated for new tunnel `bc6ecd05` |
| `cloudflared-credentials` secret (K8s) | Reloaded with new tunnel credentials |
