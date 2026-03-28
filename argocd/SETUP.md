# ArgoCD GitOps Setup Summary

## 📦 What Was Prepared

### 1. ArgoCD Helm Chart (Latest Version 9.4.17)

* **Location**: `argocd/argo-cd/`
* **Version**: ArgoCD v3.3.6 (Chart 9.4.17)
* **Status**: Downloaded and ready for installation

### 2. Custom Configuration Files

#### `argocd/values.yaml`

* Custom ArgoCD configuration optimized for P2-POS
* Resource limits defined
* RBAC policies configured
* Insecure mode enabled (for local development)

#### `argocd/project.yaml`

* P2-POS AppProject resource
* Defines allowed destinations and resources
* Cluster and namespace resource whitelists

#### `argocd/p2-pos-app.yaml`

* P2-POS Application resource
* Points to GitHub repository: `https://github.com/jayr-abawag/p2-pos.git`
* Watches `k8s/mc-pos/` directory
* Auto-sync enabled with self-heal

### 3. Installation Scripts

#### `argocd/install-argocd.sh`

* Automated installation script
* Checks prerequisites (kubectl, helm)
* Installs ArgoCD using Helm
* Creates project and application
* Displays access credentials

### 4. Documentation

#### `argocd/README.md`

* Complete ArgoCD setup guide
* Configuration details
* Troubleshooting tips
* Best practices

## 🚀 How to Use

### Quick Installation (Recommended)

```Shell
# Make script executable
chmod +x argocd/install-argocd.sh

# Run installation script
./argocd/install-argocd.sh
```

This will:

1. ✅ Check prerequisites
2. ✅ Install ArgoCD using Helm
3. ✅ Create P2-POS project
4. ✅ Create P2-POS application
5. ✅ Display access credentials

### Manual Installation

```Shell
# 1. Create namespace
kubectl create namespace argocd

# 2. Install ArgoCD
helm install argocd -n argocd \
  -f argocd/values.yaml \
  ./argocd/argo-cd

# 3. Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=300s

# 4. Create project and application
kubectl apply -f argocd/project.yaml
kubectl apply -f argocd/p2-pos-app.yaml
```

### Access ArgoCD UI

```Shell
# Port forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser: https://localhost:8080
# Username: admin
# Password: (displayed by install script)
```

## 🔄 GitOps Workflow

### Development Workflow

1. **Make code changes** to frontend or backend
2. **Commit and push** to GitHub `main` branch
3. **GitHub Actions** automatically:
   * Builds Docker images
   * Pushes to GHCR with `:latest` tag
4. **ArgoCD automatically**:
   * Detects image changes
   * Syncs to Kubernetes cluster
   * Updates deployments with new images

### Infrastructure Changes

1. **Update Kubernetes manifests** in `k8s/mc-pos/`
2. **Commit and push** to GitHub
3. **ArgoCD automatically**:
   * Detects manifest changes
   * Syncs to Kubernetes cluster
   * Updates resources

## 📊 Monitoring

### Using ArgoCD UI

1. Open `https://localhost:8080`
2. Login with admin credentials
3. View P2-POS application status
4. Check sync status and resource health

### Using ArgoCD CLI

```Shell
# Install ArgoCD CLI
# macOS
brew install argocd

# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Login to ArgoCD
argocd login localhost:8080 --insecure --username admin --password <password>

# Check application status
argocd app get p2-pos

# List applications
argocd app list

# Watch application sync
argocd app watch p2-pos
```

## 🎯 Key Features

### Auto-Sync

* ArgoCD watches the Git repository every 3 minutes
* Automatically syncs changes when detected
* Self-heals if resources drift from desired state

### Rollback

* Easy rollback to previous Git commits
* View deployment history in ArgoCD UI
* Rollback via UI or CLI

### Multi-Environment Support

* Create multiple applications for different environments
* Use different branches or values files
* Separate namespaces per environment

## 🔐 Security Notes

### Current Setup (Development)

* Insecure mode enabled (HTTP access)
* Default admin password
* No TLS verification

### Production Recommendations

* ✅ Enable TLS/HTTPS
* ✅ Change default admin password
* ✅ Disable insecure mode
* ✅ Use RBAC for access control
* ✅ Enable audit logging
* ✅ Use private Git repositories
* ✅ Rotate secrets regularly

## 📁 File Structure

```
argocd/
├── argo-cd/                  # ArgoCD Helm chart (v9.4.17)
│   ├── Chart.yaml
│   ├── values.yaml          # Default values
│   └── templates/           # Kubernetes templates
├── values.yaml              # Custom configuration
├── project.yaml             # P2-POS AppProject
├── p2-pos-app.yaml          # P2-POS Application
├── install-argocd.sh        # Installation script
├── README.md                # Detailed guide
└── SETUP.md                 # This file
```

## 🎉 Benefits

### Why GitOps with ArgoCD?

1. **Declarative**: Desired state defined in Git
2. **Automated**: Zero-touch deployments
3. **Versioned**: All changes tracked in Git
4. **Auditable**: Complete deployment history
5. **Revertible**: Easy rollback to any commit
6. **Consistent**: Same process across environments
7. **Self-Healing**: Automatic drift correction

### vs Manual Deployment

| Manual Deployment        | GitOps with ArgoCD      |
| ------------------------ | ----------------------- |
| `kubectl apply` manually | Git push triggers sync  |
| No version history       | Git provides history    |
| Manual rollbacks         | Easy rollback via Git   |
| Drift detection manual   | Automatic self-healing  |
| Error-prone              | Consistent and reliable |

## 📚 Next Steps

1. ✅ Install ArgoCD using the provided script
2. ✅ Access ArgoCD UI and verify P2-POS application
3. ✅ Test auto-sync by making a code change
4. ✅ Configure production settings (TLS, RBAC, etc.)
5. ✅ Set up monitoring and alerting

***

**Status**: Ready for installation
**ArgoCD Version**: v3.3.6 (Chart 9.4.17)
**Prepared**: 2026-03-28
