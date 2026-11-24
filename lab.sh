#!/usr/bin/env bash
# Kubernetes lab, level by level.
# Usage: ./lab.sh up | addon <name> | check <level|all> | progress [--open] | status | down
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
  check)
    lvl=${2:?"level: 1-9 or all"}
    if [[ $lvl == all ]]; then
      rc=0; for i in 1 2 3 4 5 6 7 8 9; do bash "level-$i/check.sh" || rc=1; done; exit $rc
    fi
    [[ -f "level-$lvl/check.sh" ]] || { echo "No check for level $lvl"; exit 1; }
    bash "level-$lvl/check.sh" ;;
  progress)
    done_n=0; G=; N=; [[ -t 1 ]] && G=$'\e[32m' N=$'\e[0m'
    for i in 1 2 3 4 5 6 7 8 9; do
      d=$(awk -v l="$i" '$1 == l { print $2 }' .progress 2>/dev/null)
      if [[ -n $d ]]; then printf '  %s✔%s level %s  %s\n' "$G" "$N" "$i" "$d"; done_n=$((done_n + 1)); else printf '  · level %s\n' "$i"; fi
    done
    bar=$(printf '%*s' "$done_n" '' | tr ' ' '#')$(printf '%*s' $((9 - done_n)) '' | tr ' ' '.')
    printf '\n  [%s] %s/9\n' "$bar" "$done_n"
    if [[ ${2:-} == --open ]]; then
      lang=${LAB_LANG:-$([[ "${LANG:-}" == es* ]] && echo es || echo en)}
      python3 - "$lang" <<'PY'
import json, sys
done = {}
try:
    for line in open('.progress'):
        level, day = line.split()
        done[level] = day
except FileNotFoundError:
    pass
page = open('checks/progress.html').read()
page = page.replace('/*PROGRESS*/{}', json.dumps(done)).replace("/*LANG*/'en'", json.dumps(sys.argv[1]))
open('.progress.html', 'w').write(page)
PY
      if command -v open >/dev/null; then open .progress.html; elif command -v xdg-open >/dev/null; then xdg-open .progress.html; else echo "Open .progress.html in a browser"; fi
    fi ;;
  status) k get nodes -L role,karpenter.sh/nodepool; echo; h list -A ;;
  down) kind delete cluster --name lab ;;
  *) echo "Usage: ./lab.sh up | addon <name> | check <level|all> | progress [--open] | status | down"; exit 1 ;;
esac
