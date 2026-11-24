#!/usr/bin/env bash
# Level 2 check: the four controllers end healthy, shop-web on podinfo 6.7.1.
source "$(dirname "$0")/../checks/lib.sh"
header "Level 2 · Workloads" "Nivel 2 · Workloads"
task "Deployment shop-web has all replicas ready" "El Deployment shop-web tiene todas sus réplicas listas" \
     "kubectl apply -f level-2/web.yaml; if a rollout is stuck: kubectl rollout undo deployment/shop-web -n shop" "kubectl apply -f level-2/web.yaml; si un rollout se atascó: kubectl rollout undo deployment/shop-web -n shop" \
     deploy_ready shop shop-web
task "shop-web runs podinfo 6.7.1 (the rolling update)" "shop-web usa podinfo 6.7.1 (el rolling update)" \
     "kubectl set image deployment/shop-web web=ghcr.io/stefanprodan/podinfo:6.7.1 -n shop" "kubectl set image deployment/shop-web web=ghcr.io/stefanprodan/podinfo:6.7.1 -n shop" \
     image_tag_is shop shop-web 6.7.1
task "StatefulSet redis has both replicas ready" "El StatefulSet redis tiene sus dos réplicas listas" \
     "kubectl apply -f level-2/redis.yaml and watch: kubectl get pods -n shop -w" "kubectl apply -f level-2/redis.yaml y mira: kubectl get pods -n shop -w" \
     sts_ready shop redis
task "Each redis pod has its own bound PVC" "Cada pod de redis tiene su PVC Bound" \
     "kubectl get pvc -n shop: expect data-redis-0 and data-redis-1" "kubectl get pvc -n shop: deben salir data-redis-0 y data-redis-1" \
     bash -c "$(declare -f k jp pvc_bound); CTX=$CTX; pvc_bound shop data-redis-0 && pvc_bound shop data-redis-1"
task "DaemonSet log-agent is ready on every node it targets" "El DaemonSet log-agent está listo en todos sus nodos" \
     "kubectl apply -f level-2/log-agent.yaml; kubectl get ds -n observability" "kubectl apply -f level-2/log-agent.yaml; kubectl get ds -n observability" \
     ds_ready observability log-agent
task "Job db-migrate succeeded" "El Job db-migrate terminó bien" \
     "kubectl apply -f level-2/job.yaml; kubectl logs job/db-migrate -n shop" "kubectl apply -f level-2/job.yaml; kubectl logs job/db-migrate -n shop" \
     condition job shop db-migrate Complete
finish 2
