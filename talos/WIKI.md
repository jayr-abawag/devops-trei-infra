# Talos Linux Cluster Wiki

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Installation](#installation)
- [Configuration](#configuration)
- [Operations](#operations)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)
- [Security](#security)

---

## Overview

### What is Talos Linux?

**Talos Linux** is an immutable, minimal, and secure Linux OS designed specifically for Kubernetes. It provides:

- **Immutable Infrastructure**: No shell access, all configuration via API
- **Minimal Attack Surface**: Only essential components for running Kubernetes
- **API-First**: All management done through `talosctl` CLI
- **Built-in Security**: Encrypted, signed, and verified by default

### Cluster Specifications

| Property | Value |
|----------|-------|
| **Cluster Name** | venus |
| **Control Plane IP** | 192.168.0.240 |
| **API Endpoint** | https://192.168.0.240:6443 |
| **Talos Version** | v1.7.0 |
| **Kubernetes Version** | v1.29.0 |
| **Storage Provider** | Longhorn |
| **Network** | Cloudflare Tunnel (Optional) |

---

## Architecture

### Node Types

#### Control Plane Node
- **IP**: 192.168.0.240
- **Role**: Control Plane + Etcd + Workloads (single-node cluster)
- **Components**:
  - API Server
  - Scheduler
  - Controller Manager
  - Etcd (distributed key-value store)
  - Kubelet
  - CNI (Cilium)

#### Worker Nodes (Optional)
- Additional compute nodes can be added using `worker.yaml`
- Designed for scaling workloads

### Storage Architecture

```
┌─────────────────────────────────────────┐
│         Kubernetes Cluster              │
│  ┌──────────────────────────────────┐  │
│  │     Longhorn CSI Driver          │  │
│  │  (Distributed Block Storage)     │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │    Cilium CNI                    │  │
│  │  (Networking & Network Policies) │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│         Talos Linux OS                  │
│  (Immutable, API-managed, Secure)       │
└─────────────────────────────────────────┘
```

---

## Installation

### Prerequisites

#### Hardware Requirements
- **CPU**: 2 cores minimum, 4 cores recommended
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 20GB minimum, SSD recommended
- **Network**: Ethernet connection

#### Software Requirements
- **talosctl** v1.7.0+
- **kubectl** v1.29.0+
- **YAML processor** (for config editing)

### Quick Start

<details>
<summary><strong>Step 1: Install talosctl</strong></summary>

```bash
# Linux (Intel/AMD)
curl -LO https://talos.dev/talosctl-v1.7.0-linux-amd64
sudo install talosctl-v1.7.0-linux-amd64 /usr/local/bin/talosctl

# macOS (Apple Silicon)
curl -LO https://talos.dev/talosctl-v1.7.0-darwin-arm64
sudo install talosctl-v1.7.0-darwin-arm64 /usr/local/bin/talosctl

# Windows (PowerShell)
iwr -useb https://talos.dev/talosctl-v1.7.0-windows-amd64.exe -Outfile talosctl.exe
```

</details>

<details>
<summary><strong>Step 2: Boot Talos ISO</strong></summary>

1. Download Talos ISO from [GitHub Releases](https://github.com/siderolabs/talos/releases)
2. Mount ISO on target hardware
3. Boot from ISO/USB
4. Note the IP address (DHCP or static)

</details>

<details>
<summary><strong>Step 3: Generate Configuration</strong></summary>

```bash
talosctl gen config venus https://192.168.0.240:6443
```

This generates:
- `controlplane.yaml` - Control plane configuration
- `worker.yaml` - Worker node configuration
- `talosconfig` - Talos CLI configuration

</details>

<details>
<summary><strong>Step 4: Apply Configuration</strong></summary>

```bash
talosctl apply-config --insecure \
  --nodes 192.168.0.240 \
  --file controlplane.yaml
```

**Note**: `--insecure` is only needed for initial installation.

</details>

<details>
<summary><strong>Step 5: Bootstrap Cluster</strong></summary>

```bash
# Monitor bootstrap progress
talosctl dashboard --nodes 192.168.0.240

# Generate kubeconfig
talosctl kubeconfig --nodes 192.168.0.240 ./kubeconfig

# Set KUBECONFIG
export KUBECONFIG=./kubeconfig

# Verify cluster
kubectl get nodes
```

</details>

---

## Configuration

### Control Plane Configuration

Key settings in `controlplane.yaml`:

```yaml
# Cluster-wide configuration
cluster:
  clusterName: venus
  network:
    dnsDomain: cluster.local
    podSubnets:
      - 10.244.0.0/16
    serviceSubnets:
      - 10.96.0.0/12

# Allow workloads on control plane (single-node setup)
allowSchedulingOnControlPlanes: true

# Machine configuration
machine:
  type: controlplane
  install:
    disk: /dev/sda
    image: ghcr.io/siderolabs/installer:v1.7.0

  # Network configuration
  network:
    hostname: controlplane-1
    interfaces:
      - deviceSelector:
          busPath: "0:*"  # Adjust for your hardware
        addresses:
          - 192.168.0.240/24
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.0.1

  # Kubernetes configuration
  kubelet:
    extraArgs:
      feature-gates: MixedProtocolLBService=true
```

### Worker Configuration

```yaml
machine:
  type: worker
  install:
    disk: /dev/sda
    image: ghcr.io/siderolabs/installer:v1.7.0

  # Join existing cluster
  network:
    hostname: worker-1
```

### Common Configuration Tasks

<details>
<summary><strong>Enable Control Plane Scheduling</strong></summary>

Edit `controlplane.yaml`:

```yaml
# Add this at the top level
allowSchedulingOnControlPlanes: true
```

Apply:

```bash
talosctl apply-config \
  --nodes 192.168.0.240 \
  --file controlplane.yaml
```

</details>

<details>
<summary><strong>Add Static IP</strong></summary>

Edit machine configuration:

```yaml
machine:
  network:
    interfaces:
      - deviceSelector:
          busPath: "0:*"
        addresses:
          - 192.168.0.240/24
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.0.1
        mtu: 1500
```

</details>

<details>
<summary><strong>Configure DNS</strong></summary>

```yaml
machine:
  network:
    nameservers:
      - 1.1.1.1
      - 1.0.0.1
```

</details>

---

## Operations

### Daily Operations

#### Viewing Logs

```bash
# Talos service logs
talosctl logs --nodes 192.168.0.240 etcd

# Kubernetes pod logs
kubectl logs -n namespace pod-name

# All pod logs
kubectl logs -l app=application-name
```

#### Managing Services

```bash
# List all Talos services
talosctl services --nodes 192.168.0.240

# Restart a service
talosctl restart --nodes 192.168.0.240 kubelet

# Check service status
talosctl service etcd --nodes 192.168.0.240
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

#### Upgrading Kubernetes

```bash
# Edit machine config
talosctl edit machineconfig --nodes 192.168.0.240

# Change:
# cluster.apiServer.image: registry.k8s.io/kube-apiserver:v1.30.0

# Apply config
talosctl apply-config --nodes 192.168.0.240 --mode=no-reboot
```

### Backup & Recovery

#### Etcd Backup

```bash
# Snapshot etcd database
talosctl etcd snapshot save --nodes 192.168.0.240 backup.db

# List snapshots
talosctl etcd snapshot list --nodes 192.168.0.240

# Restore from snapshot
talosctl etcd restore --nodes 192.168.0.240 backup.db
```

#### Configuration Backup

```bash
# Export current configuration
talosctl get machineconfig --nodes 192.168.0.240 -o yaml > backup-config.yaml

# Backup kubeconfig
cp kubeconfig kubeconfig.backup
```

---

## Troubleshooting

### Common Issues

#### Cluster Won't Bootstrap

**Symptoms**: `kubectl get nodes` returns error or connection timeout

**Solutions**:

1. Check Talos services:
   ```bash
   talosctl services --nodes 192.168.0.240
   ```

2. Check etcd logs:
   ```bash
   talosctl logs --nodes 192.168.0.240 etcd
   ```

3. Verify network connectivity:
   ```bash
   ping 192.168.0.240
   curl -k https://192.168.0.240:6443/healthz
   ```

4. Check dashboard:
   ```bash
   talosctl dashboard --nodes 192.168.0.240
   ```

#### Pods Not Starting

**Symptoms**: Pods stuck in `Pending` or `ImagePullBackOff` state

**Solutions**:

1. Check pod status:
   ```bash
   kubectl describe pod pod-name
   ```

2. Check events:
   ```bash
   kubectl get events --sort-by=.metadata.creationTimestamp
   ```

3. Verify nodes are Ready:
   ```bash
   kubectl get nodes -o wide
   ```

4. Check CNI:
   ```bash
   kubectl -n kube-system get pods -l k8s-app=kube-router
   ```

#### Storage Issues

**Symptoms**: Longhorn volumes failing to attach

**Solutions**:

1. Check Longhorn pods:
   ```bash
   kubectl get pods -n longhorn-system
   ```

2. Check storage nodes:
   ```bash
   kubectl get nodes -o custom-columns=NAME:.metadata.name,STORAGE:.status.allocatable.storage\.ephemeralstorage
   ```

3. Verify CSI drivers:
   ```bash
   kubectl get csidrivers
   ```

### Debug Mode

```bash
# Enable debug logging
talosctl edit mc --nodes 192.168.0.240
# Set: machine.logging.format: json
# Set: machine.logging.debug: true

# View debug logs
talosctl dmesg --nodes 192.168.0.240

# Network debugging
talosctl interfaces --nodes 192.168.0.240
talosctl routes --nodes 192.168.0.240
```

### Recovery Procedures

<details>
<summary><strong>Recover from Bad Configuration</strong></summary>

If you apply a bad configuration and lose access:

1. Boot into maintenance mode (from ISO/USB)
2. Mount the disk:
   ```bash
   talosctl mount --dev /dev/sda1 /mnt
   ```

3. Edit configuration:
   ```bash
   talosctl edit mc --mode=staging
   ```

4. Reboot and verify

</details>

<details>
<summary><strong>Reset Cluster</strong></summary>

**WARNING**: This destroys all data!

```bash
talosctl reset --nodes 192.168.0.240 --reboot
```

Then re-install from scratch.

</details>

---

## Maintenance

### Regular Tasks

#### Daily
- Monitor cluster health: `kubectl get nodes`
- Check failed pods: `kubectl get pods -A | grep -v Running`

#### Weekly
- Review logs: `talosctl logs etcd --tail 100`
- Check disk usage: `talosctl df --nodes 192.168.0.240`
- Backup etcd: `talosctl etcd snapshot save`

#### Monthly
- Update Talos: Check for new releases
- Update Kubernetes: Plan upgrade path
- Review security advisories
- Audit cluster resources

#### Quarterly
- Test backup restoration
- Review and update documentation
- Capacity planning

### Monitoring

#### Cluster Metrics

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -A

# Resource quotas
kubectl describe resourcequota
```

#### Alerts to Monitor

- **Etcd leader changes**: May indicate instability
- **API server latency**: High latency affects cluster performance
- **Disk usage**: Running out of disk space causes failures
- **Memory usage**: OOM kills indicate resource pressure

### Performance Tuning

#### Kubelet Configuration

```yaml
machine:
  kubelet:
    extraArgs:
      max-pods: 110
      pod-max-pids-soft-limit: -1
      system-reserved: cpu=500m,memory=500Mi
      kube-reserved: cpu=500m,memory=500Mi
      eviction-hard: memory.available<500Mi,nodefs.available<10%
```

#### Etcd Tuning

```yaml
cluster:
  etcd:
    advertisedSubnets:
      - 192.168.0.0/24
    listenSubnets:
      - 0.0.0.0/0
```

---

## Security

### Best Practices

#### 1. Network Security

```yaml
# Restrict API server access
machine:
  api:
    certSANs:
      - 192.168.0.240
      - controlplane.cluster.local
    # Remove insecure access after bootstrap
```

#### 2. RBAC Configuration

```bash
# Create admin user
kubectl create serviceaccount cluster-admin -n kube-system

# Create role binding
kubectl create clusterrolebinding cluster-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:cluster-admin
```

#### 3. Pod Security

```yaml
# Enable Pod Security Admission
kubectl label --overwrite ns default \
  pod-security.kubernetes.io/enforce=restricted
```

#### 4. Network Policies

```yaml
# Default deny all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Certificate Management

```bash
# View certificate expiration
talosctl get certificates --nodes 192.168.0.240

# Rotate certificates
talosctl rotate certificates --nodes 192.168.0.240

# Force specific certificate rotation
talosctl rotate \
  --nodes 192.168.0.240 \
  --certificates=kubelet,apiserver
```

### Security Scanning

```bash
# Scan for vulnerabilities
trivy image python:3.12

# Check pod security
kubectl auth can-i list pods --as=system:anonymous

# Audit logs
kubectl logs -n kube-system -l component=kube-apiserver | grep audit
```

### Compliance

#### CIS Benchmark

```bash
# Run CIS benchmark checks
kube-bench run --targets node
```

#### Falco (Runtime Security)

```bash
# Install Falco
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco
```

---

## Advanced Topics

### Multi-Node Cluster

To add worker nodes:

1. Generate worker config:
   ```bash
   talosctl gen config venus https://192.168.0.240:6443
   ```

2. Apply to worker nodes:
   ```bash
   talosctl apply-config \
     --nodes 192.168.0.241 \
     --file worker.yaml
   ```

3. Verify:
   ```bash
   kubectl get nodes
   ```

### Disaster Recovery

#### Off-site Backup Strategy

```bash
# Automated etcd backup script
#!/bin/bash
DATE=$(date +%Y%m%d-%H%M%S)
talosctl etcd snapshot save \
  --nodes 192.168.0.240 \
  /backup/etcd-$DATE.db

# Copy to remote storage
rclone copy /backup remote:backups/talos/

# Keep last 30 days
find /backup -name "etcd-*.db" -mtime +30 -delete
```

#### High Availability

For HA, deploy 3+ control plane nodes:

```yaml
# Add to controlplane.yaml for each node
cluster:
  controlPlane:
    endpoint: https://192.168.0.240:6443
  etcd:
    advertisedSubnets:
      - 192.168.0.0/24
```

### Integration with External Services

#### Cloudflare Tunnel

```yaml
# Install cloudflared
kubectl apply -f k8s/cloudflare-tunnel.yaml

# Configure tunnel
cloudflared tunnel route dns venus cluster.example.com
```

#### Monitoring Stack

```bash
# Install Prometheus Operator
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack
```

---

## Appendix

### Useful Commands

```bash
# Talos
talosctl version                    # Show versions
talosctl get members                # List cluster members
talosctl get kubeconfig             # Get kubeconfig
talosctl health                     # Check cluster health
talosctl df                         # Disk usage
talosctl processes                  # List processes
talosctl read /var/log/kubelet.log  # Read file from node

# Kubernetes
kubectl cluster-info                # Cluster info
kubectl api-resources               # List resources
kubectl get all -A                  # Get everything
kubectl describe node <name>        # Node details
kubectl logs -f                     # Follow logs
kubectl exec -it <pod> -- sh        # Shell into pod

# Debug
kubectl get events --sort-by=.lastTimestamp
kubectl get nodes -o wide
kubectl top nodes
kubectl top pods -A
```

### File Locations

- `talos.commad` - Command reference
- `controlplane.yaml` - Control plane configuration
- `worker.yaml` - Worker configuration
- `talosconfig` - Talos CLI config
- `kubeconfig` - Kubernetes config
- `k8s/` - Kubernetes manifests
- `docker/` - Docker compose files

### Support Resources

- [Talos Documentation](https://www.talos.dev)
- [Talos GitHub](https://github.com/siderolabs/talos)
- [Talos Slack](https://slack.dev.talos-systems.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

### Changelog

- **2025-03-27**: Initial wiki creation
- **Cluster**: venus (192.168.0.240)
- **Versions**: Talos v1.7.0, K8s v1.29.0

---

*Last updated: 2025-03-27*
