#!/usr/bin/env bash
# Reproduces a classic node-maintenance incident on lab-worker2:
#  1. fills the node with memory requests via "app-load" (as Karpenter does when it bin-packs),
#  2. starts a rolling update of the log-agent DaemonSet,
#  3. the new agent pod stays Pending: it can only run on that node, and the node is full.
# With --overprovisioning a negative-priority placeholder pod reserves room first.
set -euo pipefail
cd "$(dirname "$0")/.."
NODE=lab-worker2
kubectl config use-context kind-lab >/dev/null
kubectl apply -f level-2/log-agent.yaml >/dev/null
kubectl rollout status ds/log-agent -n observability --timeout=120s >/dev/null
# Wait until old agent pods from a previous rollout are gone: they still hold requests.
while [[ -n "$(kubectl get pods -A -o jsonpath='{.items[?(@.metadata.deletionTimestamp)].metadata.name}')" ]]; do sleep 2; done
kubectl create namespace shop --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl delete deploy app-load -n shop --ignore-not-found --wait >/dev/null

if [[ "${1:-}" == "--overprovisioning" ]]; then
  kubectl apply -f level-5/overprovisioning.yaml >/dev/null
  kubectl rollout status deploy/overprovisioning -n kube-system --timeout=120s >/dev/null
fi
while [[ -n "$(kubectl get pods -A -o jsonpath='{.items[?(@.metadata.deletionTimestamp)].metadata.name}')" ]]; do sleep 2; done

to_mi() { # converts 1Gi, 512Mi, 1048576Ki or bytes to Mi
  local v=$1
  case $v in
    *Gi) echo $(( ${v%Gi} * 1024 ));; *Mi) echo ${v%Mi};; *Ki) echo $(( ${v%Ki} / 1024 ));;
    *) echo $(( v / 1048576 ));;
  esac
}
ALLOC=$(to_mi "$(kubectl get node $NODE -o jsonpath='{.status.allocatable.memory}')")
USED=0
for r in $(kubectl get pods -A --field-selector spec.nodeName=$NODE,status.phase!=Succeeded,status.phase!=Failed \
  -o jsonpath='{range .items[*].spec.containers[*]}{.resources.requests.memory}{" "}{end}'); do
  USED=$(( USED + $(to_mi "$r") ))
done
# Leave 32Mi free: less than the 64Mi the agent requests.
FILL=$(( ALLOC - USED - 32 ))
echo "$NODE: allocatable ${ALLOC}Mi, already requested ${USED}Mi, app-load will request ${FILL}Mi"

kubectl apply -f - >/dev/null <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-load
  namespace: shop
spec:
  replicas: 1
  selector:
    matchLabels: { app: app-load }
  template:
    metadata:
      labels: { app: app-load }
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - { key: kubernetes.io/hostname, operator: In, values: [$NODE] }
      containers:
        - name: app
          image: registry.k8s.io/pause:3.10
          resources:
            requests: { cpu: 10m, memory: ${FILL}Mi }
YAML
kubectl rollout status deploy/app-load -n shop --timeout=120s >/dev/null
echo "app-load is on: $(kubectl get pod -n shop -l app=app-load -o jsonpath='{.items[0].spec.nodeName}')"

# Rolling update of the agent: change an annotation in the pod template.
kubectl patch ds log-agent -n observability --type merge \
  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"version\":\"$(date +%s)\"}}}}}" >/dev/null
sleep 5
echo
kubectl get pods -n observability -o wide
echo
echo "The incident is ready. Continue with level-5/README.md, section \"The drain\"."
