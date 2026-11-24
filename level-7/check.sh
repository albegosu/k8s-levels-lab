#!/usr/bin/env bash
# Level 7 check: data that outlives its pod, on a volume tied to one node.
source "$(dirname "$0")/../checks/lib.sh"
header "Level 7 · Storage and cloud" "Nivel 7 · Almacenamiento y nube"
task "PVC data is Bound" "El PVC data está Bound" \
     "kubectl apply -f level-7/pvc.yaml -f level-7/pod-with-disk.yaml (WaitForFirstConsumer needs a pod)" "kubectl apply -f level-7/pvc.yaml -f level-7/pod-with-disk.yaml (WaitForFirstConsumer necesita un pod)" \
     pvc_bound sandbox data
task "Pod with-disk is Running" "El pod with-disk está Running" \
     "kubectl apply -f level-7/pod-with-disk.yaml" "kubectl apply -f level-7/pod-with-disk.yaml" \
     pod_phase sandbox with-disk Running
task "/data/file survived a pod restart and says hello" "/data/file sobrevivió al reinicio del pod y dice hello" \
     "kubectl exec -n sandbox with-disk -- sh -c 'echo hello > /data/file'" "kubectl exec -n sandbox with-disk -- sh -c 'echo hello > /data/file'" \
     test "$(k exec -n sandbox with-disk -- cat /data/file 2>/dev/null)" = hello
task "Its volume is pinned to one node (like an EBS zone)" "Su volumen está atado a un nodo (como una zona de EBS)" \
     "kubectl get pv -o yaml | grep -A8 nodeAffinity" "kubectl get pv -o yaml | grep -A8 nodeAffinity" \
     test -n "$(jp pv "$(jp pvc data -n sandbox -o jsonpath='{.spec.volumeName}')" -o jsonpath='{.spec.nodeAffinity.required}')"
finish 7
