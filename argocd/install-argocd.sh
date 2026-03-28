#!/bin/bash
# ArgoCD Installation Script for P2-POS
# This script installs ArgoCD and sets up the P2-POS application

set -e

echo "🚀 Installing ArgoCD for P2-POS GitOps deployment..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ helm not found. Please install helm first.${NC}"
    exit 1
fi

# Check if cluster is accessible
echo -e "${YELLOW}📡 Checking Kubernetes cluster connection...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Cluster connection verified${NC}"
echo ""

# Create namespace
echo -e "${YELLOW}📦 Creating argocd namespace...${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✅ Namespace created${NC}"
echo ""

# Install ArgoCD using Helm
echo -e "${YELLOW}🚀 Installing ArgoCD using Helm...${NC}"
helm install argocd -n argocd \
    -f argocd/values.yaml \
    ./argocd/argo-cd \
    --wait --timeout 5m
echo -e "${GREEN}✅ ArgoCD installed${NC}"
echo ""

# Wait for ArgoCD server to be ready
echo -e "${YELLOW}⏳ Waiting for ArgoCD server to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
echo -e "${GREEN}✅ ArgoCD server is ready${NC}"
echo ""

# Create P2-POS project
echo -e "${YELLOW}📁 Creating P2-POS AppProject...${NC}"
kubectl apply -f argocd/project.yaml
echo -e "${GREEN}✅ Project created${NC}"
echo ""

# Create P2-POS application
echo -e "${YELLOW}📦 Creating P2-POS Application...${NC}"
kubectl apply -f argocd/p2-pos-app.yaml
echo -e "${GREEN}✅ Application created${NC}"
echo ""

# Get initial admin password
echo -e "${YELLOW}🔑 Getting initial admin password...${NC}"
INITIAL_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "argocd-server-$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}' | awk -F'-' '{print $3}')")
echo -e "${GREEN}✅ Initial password: ${INITIAL_PASSWORD}${NC}"
echo ""

# Print access information
echo "================================================"
echo -e "${GREEN}🎉 ArgoCD installation complete!${NC}"
echo "================================================"
echo ""
echo "📝 Access ArgoCD UI:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Open: https://localhost:8080"
echo ""
echo "🔐 Login Credentials:"
echo "   Username: admin"
echo "   Password: ${INITIAL_PASSWORD}"
echo ""
echo "📊 ArgoCD CLI Commands:"
echo "   # Login to ArgoCD"
echo "   argocd login localhost:8080 --insecure --username admin --password ${INITIAL_PASSWORD}"
echo ""
echo "   # Check application status"
echo "   argocd app get p2-pos"
echo ""
echo "   # Sync application manually"
echo "   argocd app sync p2-pos"
echo ""
echo "   # Watch application sync"
echo "   argocd app watch p2-pos"
echo ""
echo "📖 For more information, see: argocd/README.md"
echo "================================================"
