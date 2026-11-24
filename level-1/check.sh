#!/usr/bin/env bash
# Level 1 check. Mission: leave a pod called hello running in sandbox, labelled level=1.
source "$(dirname "$0")/../checks/lib.sh"
header "Level 1 · Fundamentals" "Nivel 1 · Fundamentos"
task "kubectl points at the lab cluster" "kubectl apunta al clúster del lab" \
     "Run: kubectl config use-context kind-lab" "Ejecuta: kubectl config use-context kind-lab" \
     test "$(kubectl config current-context)" = kind-lab
task "Namespace sandbox exists" "Existe el namespace sandbox" \
     "kubectl create namespace sandbox" "kubectl create namespace sandbox" \
     exists ns sandbox
task "Pod hello is Running in sandbox" "El pod hello está Running en sandbox" \
     "kubectl apply -f level-1/pod.yaml (you deleted it in the exercises)" "kubectl apply -f level-1/pod.yaml (lo borraste en los ejercicios)" \
     pod_phase sandbox hello Running
task "Pod hello has the label level=1" "El pod hello tiene la label level=1" \
     "kubectl label pod hello -n sandbox level=1, then kubectl get pods -n sandbox --show-labels" "kubectl label pod hello -n sandbox level=1 y luego kubectl get pods -n sandbox --show-labels" \
     test "$(jp pod hello -n sandbox -o jsonpath='{.metadata.labels.level}')" = 1
task "The broken pod is gone" "El pod broken ya no existe" \
     "kubectl delete -f level-1/pod-broken.yaml" "kubectl delete -f level-1/pod-broken.yaml" \
     not exists pod broken -n sandbox
finish 1
