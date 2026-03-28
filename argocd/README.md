# ArgoCD GitOps Setup for P2-POS

This directory contains ArgoCD Helm chart and manifests for GitOps-based deployment of the P2-POS system.

## 📋 What is ArgoCD?

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It automatically deploys and syncs applications from your Git repository to your Kubernetes cluster.

## 🚀 Quick Start

### 1. Install ArgoCD using Helm

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
helm install argocd -n argocd \
  -f argocd/values.yaml \
  ./argocd/argo-cd

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### 2. Access ArgoCD UI

```bash
# Port forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser: https://localhost:8080
# Username: admin
# Password: (see below)
```

### 3. Get Initial Admin Password

```bash
# The initial password is the pod name
argocd-server-<pod-id>

# Or get it from ArgoCD secrets
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 4. Create P2-POS Project and Application

```bash
# Apply the project
kubectl apply -f argocd/project.yaml

# Apply the application
kubectl apply -f argocd/p2-pos-app.yaml
```

## 🔄 How It Works

### GitOps Workflow

1. **Push code changes** to GitHub (frontend or backend)
2. **GitHub Actions** automatically builds and pushes Docker images to GHCR
3. **Update Kubernetes manifests** with new image tags (if needed)
4. **ArgoCD detects changes** and syncs to Kubernetes cluster
5. **Application updates** automatically with zero downtime

### ArgoCD Sync Modes

- **Automatic**: ArgoCD watches the Git repo and auto-syncs changes
- **Manual**: Trigger sync manually from ArgoCD UI or CLI
- **Scheduled**: Sync at specific intervals

## 📁 File Structure

```
argocd/
├── argo-cd/              # ArgoCD Helm chart
│   ├── Chart.yaml
│   ├── values.yaml       # Default ArgoCD values
│   └── templates/        # ArgoCD Kubernetes templates
├── values.yaml           # Custom ArgoCD configuration
├── project.yaml          # P2-POS AppProject
├── p2-pos-app.yaml       # P2-POS Application
└── README.md             # This file
```

## 🛠️ Configuration

### ArgoCD Values (`values.yaml`)

- **Server Settings**: Domain, insecure mode (for local dev)
- **Resources**: CPU/memory limits for ArgoCD components
- **RBAC**: Role-based access control policies
- **Notifications**: Disabled by default

### Application (`p2-pos-app.yaml`)

- **Source**: GitHub repo with Kubernetes manifests
- **Path**: `k8s/mc-pos` directory
- **Destination**: `mc-pos` namespace
- **Sync Policy**: Auto-sync with self-heal enabled

## 📊 Monitoring

### Check ArgoCD Status

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check application status
argocd app get p2-pos

# List all applications
argocd app list

# Check sync status
argocd app sync p2-pos --server argocd.coffeecoding.co
```

### View Application Logs

```bash
# ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f

# ArgoCD repo-server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server -f

# Application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f
```

## 🔄 Deployment Workflow

### Deploy Frontend Changes

1. Make changes to `frontend/`
2. Commit and push to `main` branch
3. GitHub Actions builds and pushes to GHCR
4. ArgoCD detects changes and syncs automatically

### Deploy Backend Changes

1. Make changes to `backend/`
2. Commit and push to `main` branch
3. GitHub Actions builds and pushes to GHCR
4. ArgoCD detects changes and syncs automatically

### Deploy Infrastructure Changes

1. Update Kubernetes manifests in `k8s/mc-pos/`
2. Commit and push to `main` branch
3. ArgoCD detects changes and syncs automatically

## 🎯 Best Practices

### Image Tagging Strategy

- Use `latest` for development (auto-sync)
- Use semantic versioning (e.g., `v1.0.0`) for production
- Update image tags in Git, not in ArgoCD UI

### Sync Policy Recommendations

- **Development**: Auto-sync enabled
- **Staging**: Auto-sync with manual approval
- **Production**: Manual sync only

### Resource Management

- Set appropriate resource limits
- Use namespace quotas
- Enable pod disruption budgets

## 🔧 Troubleshooting

### Application Not Syncing

```bash
# Check application status
argocd app get p2-pos --server argocd.coffeecoding.co

# Check sync status
argocd app sync p2-pos --server argocd.coffeecoding.co --force

# Check for errors
argocd app operations p2-pos --server argocd.coffeecoding.co
```

### Image Pull Errors

```bash
# Verify image exists
docker pull ghcr.io/jayr-abawag/p2-pos-frontend:latest

# Check image pull secrets
kubectl get secret -n mc-pos

# Update image pull secret if needed
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=jayr-abawag \
  --docker-password=<ghp_token> \
  -n mc-pos
```

### ArgoCD Server Issues

```bash
# Restart ArgoCD server
kubectl rollout restart deployment argocd-server -n argocd

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=50
```

## 📚 Additional Resources

- [ArgoCD Documentation](https://argoproj.github.io/argo-cd/)
- [ArgoCD GitHub](https://github.com/argoproj/argo-cd)
- [GitOps Best Practices](https://www.weave.works/blog/gitops-operations-by-pull-request)

## 🔐 Security Notes

- **Change the default admin password** after first login
- **Disable insecure mode** in production
- **Use RBAC** to restrict access
- **Rotate secrets regularly**
- **Enable TLS** for all communications
- **Use private Git repositories** for sensitive manifests

## 🎉 Next Steps

1. ✅ Install ArgoCD using Helm
2. ✅ Access ArgoCD UI
3. ✅ Create P2-POS project and application
4. ✅ Verify auto-sync is working
5. ✅ Deploy your first change using GitOps!

---

**Note**: This setup is configured for development. For production, review and update security settings in `values.yaml`.
