# DevOps TREI Infrastructure

Infrastructure as Code repository for TREI applications.

## 📋 Overview

This repository contains all infrastructure configurations, Kubernetes manifests, and deployment workflows for TREI applications.

## 🏗️ Architecture

### Technologies
- **Kubernetes**: Container orchestration
- **Talos Linux**: Immutable OS for Kubernetes
- **ArgoCD**: GitOps continuous delivery
- **Cloudflare**: DNS and tunneling
- **Cert-Manager**: TLS certificate management
- **NGINX Ingress**: Ingress controller

### Applications
- **MC POS**: Point of Sale system (see [p2-pos](https://github.com/jayr-abawag/p2-pos))

## 📁 Repository Structure

```
devops-trei-infra/
├── k8s/
│   └── apps/
│       └── mc-pos/              # MC POS Kubernetes manifests
│           ├── backend.yaml
│           ├── frontend.yaml
│           ├── postgres.yaml
│           ├── ingress.yaml
│           ├── configmap-*.yaml
│           ├── secret.yaml
│           ├── namespace.yaml
│           ├── storageclass.yaml
│           ├── pv.yaml
│           ├── hpa.yaml
│           ├── pdb.yaml
│           ├── worker.yaml
│           ├── cronjob-backup.yaml
│           ├── db-bootstrap-job.yaml
│           └── kustomization.yaml
├── argocd/                      # ArgoCD configurations
├── cloudflare/                   # Cloudflare configurations
├── talos/                       # Talos Linux configurations
├── .github/workflows/
│   └── deploy-k8s.yml           # Kubernetes deployment workflow
├── scripts/
│   └── backup-k8s-postgres.sh   # PostgreSQL backup script
└── README.md
```

## 🚀 Quick Start

### Prerequisites
- kubectl configured
- helm installed
- Access to Kubernetes cluster

### Deploy MC POS Application

```bash
# Apply namespace and configs
kubectl apply -f k8s/apps/mc-pos/namespace.yaml
kubectl apply -f k8s/apps/mc-pos/secret.yaml
kubectl apply -f k8s/apps/mc-pos/configmap-backend.yaml
kubectl apply -f k8s/apps/mc-pos/configmap-frontend.yaml

# Deploy storage
kubectl apply -f k8s/apps/mc-pos/storageclass.yaml
kubectl apply -f k8s/apps/mc-pos/pv.yaml

# Deploy database
kubectl apply -f k8s/apps/mc-pos/postgres.yaml

# Wait for database to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n mc-pos --timeout=60s

# Deploy applications
kubectl apply -f k8s/apps/mc-pos/backend.yaml
kubectl apply -f k8s/apps/mc-pos/frontend.yaml

# Deploy ingress
kubectl apply -f k8s/apps/mc-pos/ingress.yaml

# Or use kustomize
kubectl apply -k k8s/apps/mc-pos/
```

### Deploy All at Once

```bash
kubectl apply -k k8s/apps/mc-pos/
```

## 🔧 Configuration

### Ingress

The ingress is configured for:
- **Domain**: pos.coffeecoding.co
- **TLS**: Automated via cert-manager
- **Annotations**: 50M body size, 60s timeout

### Services

| Service | Port | Description |
|---------|------|-------------|
| pos-backend | 3001 | Express API |
| app | 80 | Next.js frontend |
| postgres | 5432 | PostgreSQL database |

### Storage

- **Storage Class**: Longhorn (replicated storage)
- **Persistent Volume**: 20Gi for PostgreSQL
- **Backup**: Daily cron job backups to S3/MinIO

## 🔄 CI/CD

### GitHub Actions

Deployment workflow: `.github/workflows/deploy-k8s.yml`

Automatically deploys to Kubernetes when:
- Push to main branch
- Manual workflow dispatch

### ArgoCD (Optional)

For GitOps-based deployment, configure ArgoCD to sync this repository.

## 📊 Monitoring

### Application Health

```bash
# Check all pods
kubectl get pods -n mc-pos

# Check services
kubectl get svc -n mc-pos

# Check ingress
kubectl get ingress -n mc-pos

# View logs
kubectl logs -f -n mc-pos -l app=pos-backend
kubectl logs -f -n mc-pos -l app=app
```

### Backup

Automated backups run daily via cron job. Manual backup:

```bash
./scripts/backup-k8s-postgres.sh
```

## 🔒 Security

- Secrets are stored as Kubernetes secrets (not in git)
- Use sealed secrets or external secret manager for production
- RBAC policies configured per namespace
- Network policies restrict pod-to-pod communication

## 🛠️ Maintenance

### Update Application

```bash
# Update image tag
kubectl set image deployment/pos-backend pos-backend=<new-image> -n mc-pos
kubectl set image deployment/app app=<new-image> -n mc-pos

# Or edit the deployment
kubectl edit deployment pos-backend -n mc-pos
```

### Scale Application

```bash
# Scale backend
kubectl scale deployment pos-backend --replicas=3 -n mc-pos

# Scale frontend
kubectl scale deployment app --replicas=2 -n mc-pos
```

### View Logs

```bash
# Backend logs
kubectl logs -f -n mc-pos -l app=pos-backend

# Frontend logs
kubectl logs -f -n mc-pos -l app=app

# Database logs
kubectl logs -f -n mc-pos -l app=postgres
```

## 🆘 Troubleshooting

### Pod Not Starting

```bash
# Describe pod for events
kubectl describe pod -n mc-pos <pod-name>

# Check logs
kubectl logs -n mc-pos <pod-name>

# Check resources
kubectl top pods -n mc-pos
```

### Ingress Not Working

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress rules
kubectl describe ingress pos-ingress -n mc-pos

# Test DNS
nslookup pos.coffeecoding.co
```

### Database Connection Issues

```bash
# Check postgres pod
kubectl get pods -n mc-pos -l app=postgres

# Port forward to local
kubectl port-forward -n mc-pos svc/postgres 5432:5432

# Test connection
psql -h localhost -U postgres -d pos_db
```

## 📚 Related Repositories

- **[p2-pos](https://github.com/jayr-abawag/p2-pos)** - MC POS application code

## 📄 License

MIT

---

**Note**: This repository is continuously updated. Check commit history for recent changes.
