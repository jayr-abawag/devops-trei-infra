# Talos Linux Configuration

[![Talos Version](https://img.shields.io/badge/Talos-v1.7.0-blue)](https://github.com/siderolabs/talos/releases/tag/v1.7.0)
[![Kubernetes Version](https://img.shields.io/badge/Kubernetes-v1.29.0-326ce5)](https://github.com/kubernetes/kubernetes/releases/tag/v1.29.0)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> Immutable, minimal, and secure Kubernetes cluster configuration using Talos Linux.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Quick Start](#-quick-start)
- [Prerequisites](#-prerequisites)
- [Cluster Architecture](#-cluster-architecture)
- [Installation](#-installation)
- [Usage](#-usage)
- [Documentation](#-documentation)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Overview

This repository contains the complete configuration for a production-ready Talos Linux Kubernetes cluster named **"venus"**.

### What's Included

- ✅ **Talos Linux v1.7.0** - Immutable, secure OS for Kubernetes
- ✅ **Kubernetes v1.29.0** - Latest stable release
- ✅ **Longhorn Storage** - Distributed block storage
- ✅ **Cilium CNI** - High-performance networking
- ✅ **Cloudflare Tunnel** - Secure ingress (optional)
- ✅ **Automated Backups** - Etcd snapshot scripts
- ✅ **Monitoring Ready** - Prometheus integration

### Key Features

| Feature | Description |
|---------|-------------|
| **Immutable Infrastructure** | No shell access, all config via API |
| **Minimal Attack Surface** | Only essential Kubernetes components |
| **API-First Management** | Full control via `talosctl` CLI |
| **Built-in Security** | Encrypted, signed, and verified by default |
| **Single-Node Control Plane** | Perfect for homelabs and edge deployments |
| **Production-Ready Storage** | Longhorn distributed storage included |

---

## 🚀 Quick Start

### 1. Install talosctl

```bash
# Linux/macOS
curl -sL https://talos.dev/install.sh | bash

# Windows (PowerShell)
iwr -useb https://talos.dev/install.ps1 | iex
```

### 2. Boot Talos on Target Node

Download the [Talos ISO](https://github.com/siderolabs/talos/releases) and boot your server.

### 3. Apply Configuration

```bash
# Generate configuration
talosctl gen config venus https://192.168.0.240:6443

# Apply to control plane
talosctl apply-config --insecure --nodes 192.168.0.240 --file controlplane.yaml

# Generate kubeconfig
talosctl kubeconfig --nodes 192.168.0.240 ./kubeconfig

# Set KUBECONFIG
export KUBECONFIG=./kubeconfig
```

### 4. Verify Cluster

```bash
kubectl get nodes
kubectl get pods -A
```

**🎉 That's it!** Your Talos Kubernetes cluster is now running.

---

## 📦 Prerequisites

### Hardware Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **CPU** | 2 cores | 4+ cores |
| **RAM** | 4 GB | 8+ GB |
| **Storage** | 20 GB | 100+ GB SSD |
| **Network** | Ethernet | 1 Gbps |

### Software Requirements

- **talosctl** v1.7.0+ - [Install](https://www.talos.dev/latest/introduction/getting-started/install-talosctl/)
- **kubectl** v1.29.0+ - [Install](https://kubernetes.io/docs/tasks/tools/)
- **YAML processor** - For config editing

### Network Requirements

- Port **6443** - Kubernetes API
- Ports **50000-50100** - Talos API
- Port **10250** - Kubelet API
- Ports **179** - BGP (Cilium)
- Ports **TCP/UDP 30000-32767** - NodePort services

---

## 🏗️ Cluster Architecture

### Current Configuration

```
┌─────────────────────────────────────────────────────────┐
│                   Kubernetes Cluster                    │
│                    Cluster: venus                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Control Plane Node (192.168.0.240)             │  │
│  │  ┌────────────────────────────────────────────┐  │  │
│  │  │  - API Server                              │  │  │
│  │  │  - Scheduler                               │  │  │
│  │  │  - Controller Manager                      │  │  │
│  │  │  - Etcd (Single Node)                      │  │  │
│  │  │  - Longhorn Storage                        │  │  │
│  │  │  - Cilium CNI                              │  │  │
│  │  │  - Workloads Enabled                       │  │  │
│  │  └────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Storage Layer (Longhorn)                       │  │
│  │  - Distributed block storage                    │  │
│  │  - Automatic replication                        │  │
│  │  - Snapshot & backup support                   │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Networking (Cilium)                            │  │
│  │  - High-performance CNI                         │  │
│  │  - Network policies                             │  │
│  │  - Service mesh support                         │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│              Talos Linux OS (v1.7.0)                   │
│   Immutable • Minimal • API-Managed • Secure           │
└─────────────────────────────────────────────────────────┘
```

### Node Information

| Property | Value |
|----------|-------|
| **Hostname** | controlplane-1 |
| **IP Address** | 192.168.0.240 |
| **Cluster Name** | venus |
| **API Endpoint** | https://192.168.0.240:6443 |
| **Role** | Control Plane + Etcd + Workloads |

---

## 📥 Installation

### Detailed Installation Guide

For complete installation instructions, see:

- **[talos.commad](./talos.commad)** - Command reference for all setup steps
- **[WIKI.md](./WIKI.md)** - Comprehensive documentation and troubleshooting

### Installation Steps Summary

1. **Boot Talos ISO** on target hardware
2. **Generate configuration** with `talosctl gen config`
3. **Apply config** to control plane node
4. **Bootstrap cluster** and generate kubeconfig
5. **Install storage** (Longhorn) from manifests
6. **Configure ingress** (Cloudflare Tunnel, optional)

### Post-Installation Checklist

- [ ] Cluster is healthy: `kubectl get nodes`
- [ ] All pods running: `kubectl get pods -A`
- [ ] Storage ready: `kubectl get sc`
- [ ] Ingress configured: Test external access
- [ ] Backups enabled: Etcd snapshot script
- [ ] Monitoring deployed: Prometheus + Grafana

---

## 🔧 Usage

### Daily Operations

#### Viewing Cluster Status

```bash
# Node status
kubectl get nodes -o wide

# All pods
kubectl get pods -A

# Services
kubectl get svc -A

# Storage
kubectl get pv,pvc
kubectl get sc
```

#### Deploying Applications

```bash
# Create deployment
kubectl create deployment nginx --image=nginx:latest

# Expose service
kubectl expose deployment nginx --port=80 --type=NodePort

# Get service URL
kubectl get svc nginx
```

#### Managing Storage

```bash
# List storage classes
kubectl get sc

# Create PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: example-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
EOF
```

#### Logs & Debugging

```bash
# Talos logs
talosctl logs --nodes 192.168.0.240 etcd

# Pod logs
kubectl logs -f deployment/nginx

# Events
kubectl get events --sort-by=.lastTimestamp

# Pod details
kubectl describe pod pod-name
```

### Configuration Management

#### Update Machine Config

```bash
# Edit configuration interactively
talosctl edit machineconfig --nodes 192.168.0.240

# Apply configuration file
talosctl apply-config --nodes 192.168.0.240 --file controlplane.yaml

# Update without reboot
talosctl apply-config --mode=no-reboot --nodes 192.168.0.240 --file config.yaml
```

#### Upgrading Talos

```bash
# Check current version
talosctl version --nodes 192.168.0.240

# Upgrade to new version
talosctl upgrade --nodes 192.168.0.240 \
  --image ghcr.io/siderolabs/installer:v1.7.5

# Monitor upgrade
talosctl dashboard --nodes 192.168.0.240
```

### Backup & Recovery

#### Etcd Backup

```bash
# Create snapshot
talosctl etcd snapshot save --nodes 192.168.0.240 backup.db

# List snapshots
talosctl etcd snapshot list --nodes 192.168.0.240

# Restore from snapshot
talosctl etcd restore --nodes 192.168.0.240 backup.db
```

#### Configuration Backup

```bash
# Export current config
talosctl get machineconfig --nodes 192.168.0.240 -o yaml > backup.yaml

# Backup kubeconfig
cp kubeconfig kubeconfig.backup
```

---

## 📚 Documentation

### Repository Structure

```
talos-config/
├── README.md                   # This file
├── WIKI.md                     # Comprehensive documentation
├── talos.commad                # Command reference
├── controlplane.yaml           # Control plane configuration
├── worker.yaml                 # Worker node configuration
├── talosconfig                 # Talos CLI configuration
├── kubeconfig                  # Kubernetes configuration
├── k8s/                        # Kubernetes manifests
│   ├── longhorn/              # Longhorn storage
│   ├── cilium/                # Cilium CNI
│   └── monitoring/            # Prometheus stack
├── docker/                     # Docker compose files
└── longhorn-storage/          # Storage documentation
    ├── IMPLEMENTATION.md       # Setup guide
    ├── QUICKSTART.md           # Quick start
    └── STATUS.md               # Configuration status
```

### Additional Resources

- **[Talos Documentation](https://www.talos.dev/v1.7/)** - Official docs
- **[Kubernetes Documentation](https://kubernetes.io/docs/)** - K8s docs
- **[Longhorn Documentation](https://longhorn.io/docs/1.6.0/)** - Storage docs
- **[Cilium Documentation](https://docs.cilium.io/en/stable/)** - Networking docs

### Key Files

| File | Purpose |
|------|---------|
| `talos.commad` | Step-by-step command reference |
| `WIKI.md` | Complete operational documentation |
| `controlplane.yaml` | Control plane node configuration |
| `worker.yaml` | Worker node configuration |
| `k8s/` | Kubernetes resource manifests |

---

## 🔍 Troubleshooting

### Common Issues

#### Cluster Not Accessible

```bash
# Check Talos services
talosctl services --nodes 192.168.0.240

# Check API connectivity
curl -k https://192.168.0.240:6443/healthz

# Check etcd
talosctl etcd status --nodes 192.168.0.240
```

#### Pods Not Starting

```bash
# Describe pod
kubectl describe pod pod-name

# Check events
kubectl get events --sort-by=.lastTimestamp

# Check logs
kubectl logs pod-name
```

#### Storage Issues

```bash
# Check Longhorn pods
kubectl get pods -n longhorn-system

# Check volumes
kubectl get pv,pvc -A

# Check storage nodes
kubectl get nodes -o custom-columns=NAME:.metadata.name,STORAGE:.status.allocatable.storage\.ephemeralstorage
```

### Getting Help

1. Check **[WIKI.md](./WIKI.md)** for detailed troubleshooting
2. Review **[talos.commad](./talos.commad)** for common commands
3. Search [Talos GitHub Issues](https://github.com/siderolabs/talos/issues)
4. Join [Talos Slack](https://slack.dev.talos-systems.io/)

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Development Guidelines

- Keep configuration files well-documented
- Test changes in a non-production environment first
- Update documentation for any configuration changes
- Follow YAML best practices

---

## 📊 Cluster Status

### Current Versions

- **Talos**: v1.7.0
- **Kubernetes**: v1.29.0
- **Longhorn**: v1.6.0
- **Cilium**: v1.15.0

### Cluster Information

```bash
# Get cluster info
kubectl cluster-info

# Get nodes
kubectl get nodes -o wide

# Get all resources
kubectl get all -A
```

---

## 🔒 Security

### Security Best Practices

- ✅ **Immutable OS** - No shell access
- ✅ **API-Only Management** - All changes via talosctl
- ✅ **Encrypted Communication** - TLS by default
- ✅ **Minimal Attack Surface** - Only essential components
- ✅ **RBAC Enabled** - Role-based access control
- ✅ **Network Policies** - Restrict pod communication

### Security Checklist

- [ ] Remove `--insecure` flags after bootstrap
- [ ] Enable RBAC for all namespaces
- [ ] Configure network policies
- [ ] Rotate certificates regularly
- [ ] Enable audit logging
- [ ] Regular security updates
- [ ] Backup etcd regularly
- [ ] Monitor cluster access

---

## 📝 Changelog

### 2025-03-27

- 📚 Created comprehensive README
- 📖 Added WIKI.md with full documentation
- 🔧 Fixed and formatted talos.commad
- ✨ Improved documentation structure
- 🎨 Added badges and visual improvements

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **[Sidero Labs](https://www.siderolabs.com/)** - Creators of Talos Linux
- **[Kubernetes Community](https://kubernetes.io/community/)** - K8s platform
- **[Longhorn](https://longhorn.io/)** - Distributed storage solution
- **[Cilium](https://cilium.io/)** - Networking & security

---

## 📮 Contact & Support

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/talos-config/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR_USERNAME/talos-config/discussions)
- **Email**: your-email@example.com

---

<div align="center">

**Made with ❤️ for homelab and edge computing**

[⬆ Back to Top](#-overview)

</div>
