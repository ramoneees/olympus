#!/usr/bin/env bash
# OLYMPUS Bootstrap Script
# Run this ONCE to bootstrap the cluster. After this, Flux CD manages everything.
#
# Prerequisites:
#   - kubectl configured and pointing to the k3s cluster
#   - helm installed
#   - flux CLI installed (curl -s https://fluxcd.io/install.sh | bash)
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
# 4. Flux CD
# -------------------------------------------------------------------
info "Installing Flux CD..."

if ! command -v flux &>/dev/null; then
  warn "flux CLI not found. Install it first:"
  warn "  curl -s https://fluxcd.io/install.sh | bash"
  exit 1
fi

flux install --namespace=flux-system

info "Waiting for Flux controllers to be ready..."
kubectl rollout status deployment/source-controller -n flux-system --timeout=120s
kubectl rollout status deployment/kustomize-controller -n flux-system --timeout=120s
kubectl rollout status deployment/helm-controller -n flux-system --timeout=120s

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

info "Applying Flux sources..."
kubectl apply -f "$REPO_ROOT/clusters/olympus/sources.yaml"

info "Applying Flux Kustomizations (layer by layer)..."
kubectl apply -f "$REPO_ROOT/clusters/olympus/namespaces.yaml"
kubectl apply -f "$REPO_ROOT/clusters/olympus/infrastructure.yaml"
kubectl apply -f "$REPO_ROOT/clusters/olympus/databases.yaml"
kubectl apply -f "$REPO_ROOT/clusters/olympus/apps.yaml"
kubectl apply -f "$REPO_ROOT/clusters/olympus/olympus.yaml"
kubectl apply -f "$REPO_ROOT/clusters/olympus/monitoring.yaml"

info "=========================================="
info "Bootstrap complete!"
info "=========================================="
info ""
info "Flux dashboard: flux get kustomizations"
info ""
info "Next steps:"
info "  1. Set up AdGuard Home DNS rewrite: *.ramoneees.com → $(kubectl get svc -A -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo '<MetalLB IP>')"
info "  2. Verify all Kustomizations are Ready: flux get kustomizations"
info "  3. Verify all HelmReleases are Ready: flux get helmreleases -A"
