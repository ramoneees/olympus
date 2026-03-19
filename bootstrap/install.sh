#!/usr/bin/env bash
# OLYMPUS Bootstrap Script
# Run this ONCE to bootstrap the cluster. After this, ArgoCD manages everything.
#
# Prerequisites:
#   - kubectl configured and pointing to the k3s cluster
#   - helm installed
#   - Cloudflare API token ready
#
# Usage: ./bootstrap/install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

# -------------------------------------------------------------------
# 1. MetalLB
# -------------------------------------------------------------------
info "Installing MetalLB..."
helm repo add metallb https://metallb.github.io/metallb || true
helm repo update metallb
helm upgrade --install metallb metallb/metallb \
  --namespace metallb-system --create-namespace \
  -f "$SCRIPT_DIR/metallb/values.yaml" \
  --wait

info "Waiting for MetalLB controller to be ready..."
kubectl rollout status deployment/metallb-controller -n metallb-system --timeout=120s

info "Applying MetalLB IP pool and L2 advertisement..."
kubectl apply -f "$SCRIPT_DIR/metallb/ip-address-pool.yaml"

# -------------------------------------------------------------------
# 2. cert-manager
# -------------------------------------------------------------------
info "Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io || true
helm repo update jetstack
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  -f "$SCRIPT_DIR/cert-manager/values.yaml" \
  --wait

info "Waiting for cert-manager webhook to be ready..."
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s

# Check if Cloudflare secret exists
if ! kubectl get secret cloudflare-api-token -n cert-manager &>/dev/null; then
  warn "Cloudflare API token secret not found."
  warn "Create it now:"
  warn "  kubectl create secret generic cloudflare-api-token \\"
  warn "    --namespace cert-manager \\"
  warn "    --from-literal=api-token=YOUR_TOKEN_HERE"
  warn ""
  read -rp "Press Enter after creating the secret (or Ctrl+C to abort)..."
fi

info "Applying ClusterIssuers and wildcard certificate..."
kubectl apply -f "$SCRIPT_DIR/cert-manager/clusterissuer.yaml"
kubectl apply -f "$SCRIPT_DIR/cert-manager/wildcard-certificate.yaml"

info "Waiting for wildcard certificate to be ready (this may take a few minutes)..."
kubectl wait --for=condition=Ready certificate/wildcard-ramoneees-com \
  -n cert-manager --timeout=300s || \
  warn "Certificate not ready yet — check: kubectl describe certificate wildcard-ramoneees-com -n cert-manager"

# -------------------------------------------------------------------
# 3. Reflect wildcard TLS secret to other namespaces
# -------------------------------------------------------------------
info "Installing kubernetes-reflector for cross-namespace TLS secret sync..."
helm repo add emberstack https://emberstack.github.io/helm-charts || true
helm repo update emberstack
helm upgrade --install reflector emberstack/reflector \
  --namespace cert-manager \
  --wait

# Annotate the wildcard secret for reflection to all namespaces
info "Annotating wildcard TLS secret for cross-namespace reflection..."
kubectl annotate secret wildcard-ramoneees-com-tls -n cert-manager \
  reflector.v1.k8s.emberstack.com/reflection-allowed="true" \
  reflector.v1.k8s.emberstack.com/reflection-auto-enabled="true" \
  reflector.v1.k8s.emberstack.com/reflection-auto-namespaces="" \
  --overwrite

# -------------------------------------------------------------------
# 4. ArgoCD
# -------------------------------------------------------------------
info "Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo update argo
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  -f "$SCRIPT_DIR/argocd/values.yaml" \
  --wait

info "Applying ArgoCD IngressRoute..."
kubectl apply -f "$SCRIPT_DIR/argocd/ingress.yaml"

# Print initial admin password
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "not found")

info "=========================================="
info "Bootstrap complete!"
info "=========================================="
info ""
info "ArgoCD UI: https://argocd.ramoneees.com"
info "ArgoCD admin password: $ARGOCD_PASS"
info ""
info "Next steps:"
info "  1. Set up AdGuard Home DNS rewrite: *.ramoneees.com → $(kubectl get svc -A -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo '<MetalLB IP>')"
info "  2. Log into ArgoCD and change the admin password"
info "  3. Add your Gitea repo as an ArgoCD repository"
info "  4. Apply the ArgoCD Application manifests from argocd/"
