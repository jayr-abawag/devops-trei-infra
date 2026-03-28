# Install ArgoCD Image Updater

**Prerequisites**:
- ArgoCD installed and working
- kubectl configured to access cluster
- Git credentials configured for pushing to devops-trei-infra

---

## Quick Install

```bash
# 1. Create namespace (if not exists)
kubectl create namespace argocd

# 2. Apply Image Updater configuration
kubectl apply -f argocd/image-updater-config.yaml

# 3. Verify installation
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-image-updater

# 4. Check logs
kubectl logs -f -n argocd -l app.kubernetes.io/name=argocd-image-updater
```

---

## Configure Git Credentials

The Image Updater needs permission to push to `devops-trei-infra`.

### Option 1: SSH Key (Recommended)

```bash
# 1. Generate SSH key (if you don't have one)
ssh-keygen -t ed25519 -C "argocd-image-updater" -f ~/.ssh/argocd_updater

# 2. Add public key to GitHub repo
# Copy the public key:
cat ~/.ssh/argocd_updater.pub
# Go to: https://github.com/jayr-abawag/devops-trei-infra/settings/keys
# Click "Add deploy key" → Paste key → Check "Allow write access" → Add key

# 3. Create Kubernetes secret
kubectl create secret generic argocd-image-updater-git-creds \
  --from-file=sshPrivateKey=~/.ssh/argocd_updater \
  --namespace=argocd

# 4. Update ConfigMap if needed
# The config in image-updater-config.yaml already references this secret
```

### Option 2: GitHub Personal Access Token

```bash
# 1. Create PAT with repo permissions
# Go to: https://github.com/settings/tokens
# Generate new token → Select "repo" scope → Copy token

# 2. Create secret with token
kubectl create secret generic argocd-image-updater-git-creds \
  --from-literal=username=jayr-abawag \
  --from-literal=password=YOUR_PAT_HERE \
  --namespace=argocd
```

---

## Update ArgoCD Application

```bash
# 1. Delete old application (if exists)
kubectl delete application p2-pos -n argocd

# 2. Apply new application definition
kubectl apply -f argocd/apps/p2-pos.yaml

# 3. Verify
argocd app get p2-pos
argocd app list
```

---

## Test the Setup

```bash
# 1. Trigger a build
cd p2-pos/backend
echo "// test" >> src/index.ts
git add . && git commit -m "test: image updater" && git push

# 2. Watch Image Updater logs
kubectl logs -f -n argocd -l app.kubernetes.io/name=argocd-image-updater

# Expected output:
# time="..." level=info msg="Starting ArgoCD Image Updater..."
# time="..." level=info msg="Watching for image updates"
# time="..." level=info msg="New image found: ghcr.io/jayr-abawag/p2-pos-backend:sha-xyz"
# time="..." level=info msg="Updating application p2-pos"
# time="..." level=info msg="Committing changes to git"

# 3. Check devops-trei-infra repo
git log --oneline -5
# Should see: "ci: update image p2-pos to ghcr.io/jayr-abawag/p2-pos-backend:sha-xyz"

# 4. Verify ArgoCD synced
argocd app get p2-pos
kubectl get pods -n mc-pos -l app=pos-backend
```

---

## Troubleshooting

### Image Updater Not Running

```bash
# Check pod status
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-image-updater

# Describe pod
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-image-updater

# View logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater
```

### Git Push Failing

```bash
# Check secret exists
kubectl get secret argocd-image-updater-git-creds -n argocd

# Test SSH connection
kubectl run -it --rm debug --image=alpine -- sh
# Inside container:
apk add openssh-client
ssh -i /app/git-creds/sshPrivateKey -T git@github.com
```

### Images Not Updating

```bash
# Check annotations on deployment
kubectl get deployment pos-backend -n mc-pos -o yaml | grep -A 5 "argocd-image-updater"

# Check ArgoCD app annotations
argocd app get p2-pos -o yaml | grep -A 5 "argocd-image-updater"

# Verify Image Updater sees the app
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater | grep p2-pos
```

---

## Uninstall (if needed)

```bash
# Delete Image Updater
kubectl delete -f argocd/image-updater-config.yaml

# Delete secret
kubectl delete secret argocd-image-updater-git-creds -n argocd

# Revert to old workflow
# Restore .github/workflows/*-build-push.yml from git history
```

---

## Status

✅ Configuration created
⏳ Ready to install in cluster
⏳ Requires git credentials setup

**After installation**: Test with a code push to verify the full GitOps flow works!
