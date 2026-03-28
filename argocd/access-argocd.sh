#!/bin/bash
# ArgoCD Access Script for P2-POS
# This script sets up port forwarding and displays access information

export KUBECONFIG=$(pwd)/kubeconfig

echo "================================================"
echo "🎉 ArgoCD Deployment Complete!"
echo "================================================"
echo ""
echo "📊 ArgoCD Components Status:"
echo ""

# Check all pods
kubectl get pods -n argocd --insecure-skip-tls-verify

echo ""
echo "================================================"
echo "🔐 Access Credentials:"
echo "================================================"
echo ""
echo "📝 ArgoCD UI Access:"
echo "   Run this command in another terminal:"
echo "   export KUBECONFIG=$(pwd)/kubeconfig"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443 --insecure-skip-tls-verify"
echo ""
echo "   Then open: https://localhost:8080"
echo ""
echo "🔑 Login Credentials:"
echo "   Username: admin"
echo "   Password: ChX865QnZbyZ-JDq"
echo ""
echo "================================================"
echo "📦 P2-POS Application Status:"
echo "================================================"
echo ""

# Check application status
kubectl get application p2-pos -n argocd --insecure-skip-tls-verify

echo ""
echo "================================================"
echo "🚀 Quick Start Commands:"
echo "================================================"
echo ""
echo "# Login to ArgoCD CLI (after installing argocd CLI):"
echo "argocd login localhost:8080 --insecure --username admin --password ChX865QnZbyZ-JDq"
echo ""
echo "# Check application status:"
echo "argocd app get p2-pos"
echo ""
echo "# Sync application manually:"
echo "argocd app sync p2-pos"
echo ""
echo "# Watch application sync:"
echo "argocd app watch p2-pos"
echo ""
echo "================================================"
echo "📝 Next Steps:"
echo "================================================"
echo ""
echo "1. Access ArgoCD UI: https://localhost:8080"
echo "2. Login with admin credentials"
echo "3. Check P2-POS application status"
echo "4. Configure repository access (if needed)"
echo "5. Test GitOps workflow!"
echo ""
echo "================================================"
