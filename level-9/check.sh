#!/usr/bin/env bash
# Level 9 check. Mission: fix all five faults in place, without deleting them.
source "$(dirname "$0")/../checks/lib.sh"
header "Level 9 · Operations" "Nivel 9 · Operación"
task "The faults namespace exists" "Existe el namespace faults" \
     "kubectl apply -f level-9/faults.yaml" "kubectl apply -f level-9/faults.yaml" \
     exists ns faults
for app in api worker reports queue; do
  task "$app runs (fixed, not deleted)" "$app corre (arreglado, no borrado)" \
       "kubectl describe pod -n faults -l app=$app; kubectl logs -n faults deploy/$app --previous" "kubectl describe pod -n faults -l app=$app; kubectl logs -n faults deploy/$app --previous" \
       deploy_ready faults "$app"
done
task "web runs and its Service has endpoints" "web corre y su Service tiene endpoints" \
     "kubectl get svc,endpointslices -n faults; compare the selector with the pod labels" "kubectl get svc,endpointslices -n faults; compara el selector con las labels del pod" \
     bash -c "$(declare -f k jp deploy_ready endpoints_ready); CTX=$CTX; deploy_ready faults web && endpoints_ready faults web"
finish 9
