#!/usr/bin/env bash
# Level 5 check: the incident is over and the cluster is left clean.
source "$(dirname "$0")/../checks/lib.sh"
header "Level 5 · Scheduling and nodes" "Nivel 5 · Scheduling y nodos"
task "No node is cordoned" "Ningún nodo tiene cordon" \
     "kubectl get nodes; kubectl uncordon <node>" "kubectl get nodes; kubectl uncordon <nodo>" \
     test -z "$(jp nodes -o jsonpath='{.items[?(@.spec.unschedulable==true)].metadata.name}')"
task "Every log-agent pod is ready and updated" "Todos los pods de log-agent están listos y actualizados" \
     "./level-5/reproduce-incident.sh, then free room on lab-worker2 (drain or overprovisioning)" "./level-5/reproduce-incident.sh y libera sitio en lab-worker2 (drain u overprovisioning)" \
     ds_ready observability log-agent
task "log-agent was rolled out at least once (the incident)" "log-agent se actualizó al menos una vez (el incidente)" \
     "Run ./level-5/reproduce-incident.sh" "Ejecuta ./level-5/reproduce-incident.sh" \
     test "$(jp ds log-agent -n observability -o jsonpath='{.metadata.generation}')" -ge 2
task "No pod is Pending (outside the faults namespace)" "Ningún pod está Pending (fuera de faults)" \
     "kubectl get pods -A --field-selector=status.phase=Pending; read FailedScheduling" "kubectl get pods -A --field-selector=status.phase=Pending; lee FailedScheduling" \
     test -z "$(jp pods -A --field-selector=status.phase=Pending -o jsonpath='{range .items[?(@.metadata.namespace!="faults")]}{.metadata.name}{end}')"
task "Clean-up done: no app-load, no overprovisioning, no PDB" "Limpieza hecha: sin app-load, overprovisioning ni PDB" \
     "Run the commands in the Clean up section" "Ejecuta los comandos de la sección de limpieza" \
     bash -c "! kubectl --context $CTX get deploy app-load -n shop >/dev/null 2>&1 && ! kubectl --context $CTX get pdb -n shop -o name 2>/dev/null | grep -q . && ! kubectl --context $CTX get deploy -A -o name 2>/dev/null | grep -q overprovisioning"
finish 5
