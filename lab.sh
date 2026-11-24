#!/usr/bin/env bash
# Kubernetes lab, level by level.
# Usage: ./lab.sh up | addon <name> | status | down
set -euo pipefail
cd "$(dirname "$0")"
CTX=kind-lab
k() { kubectl --context "$CTX" "$@"; }
h() { helm --kube-context "$CTX" "$@"; }

repos() {
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null 2>&1 || true
  helm repo add external-secrets https://charts.external-secrets.io >/dev/null 2>&1 || true
  helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/ >/dev/null 2>&1 || true
  helm repo update >/dev/null
}

addon() {
  case "$1" in
    metrics-server)
      # kind kubelets use self-signed certificates, hence --kubelet-insecure-tls.
      h upgrade --install metrics-server metrics-server/metrics-server -n kube-system \
        --set 'args={--kubelet-insecure-tls}' --wait ;;
    gateway)
      # Envoy Gateway as the Gateway API controller.
      h upgrade --install eg oci://docker.io/envoyproxy/gateway-helm -n envoy-gateway-system \
        --create-namespace --wait
      k apply -f level-3/gateway.yaml ;;
    external-secrets)
      h upgrade --install external-secrets external-secrets/external-secrets -n external-secrets \
        --create-namespace --set installCRDs=true --wait ;;
    argocd)
      h upgrade --install argocd argo/argo-cd -n argocd --create-namespace \
        --set dex.enabled=false --set notifications.enabled=false --wait
      echo "Admin password: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d" ;;
    monitoring)
      # Trimmed-down kube-prometheus-stack (Prometheus, Alertmanager, Grafana).
      h upgrade --install kps prometheus-community/kube-prometheus-stack -n observability \
        --create-namespace -f level-8/kps-values.yaml --wait --timeout 10m ;;
    headlamp)
      # Web UI for the cluster. Its ServiceAccount is cluster-admin: lab use only.
      h upgrade --install headlamp headlamp/headlamp -n headlamp --create-namespace \
        --set nodeSelector.role=system --wait
      echo "Token: kubectl create token headlamp -n headlamp --duration=24h"
      echo "Open:  kubectl port-forward svc/headlamp -n headlamp 4466:80  ->  http://localhost:4466" ;;
    *) echo "Addons: metrics-server gateway external-secrets argocd monitoring headlamp"; exit 1 ;;
  esac
}

case "${1:-}" in
  up)
    kind get clusters | grep -qx lab || kind create cluster --config kind-lab.yaml
    kubectl config use-context "$CTX"
    k wait --for=condition=Ready node --all --timeout=180s
    repos
    addon metrics-server
    addon gateway
    addon external-secrets
    echo
    echo "Ready. Current context: $(kubectl config current-context)"
    echo "Optional: ./lab.sh addon headlamp (UI), ./lab.sh addon argocd (level 6), ./lab.sh addon monitoring (level 8)" ;;
  addon) repos; addon "${2:?addon name}" ;;
  status) k get nodes -L role,karpenter.sh/nodepool; echo; h list -A ;;
  down) kind delete cluster --name lab ;;
  *) echo "Usage: ./lab.sh up | addon <name> | status | down"; exit 1 ;;
esac
