#!/usr/bin/env bash
# Level 8 check: Prometheus scrapes shop-web and knows the Pending-pod alert.
source "$(dirname "$0")/../checks/lib.sh"
header "Level 8 · Observability" "Nivel 8 · Observabilidad"
task "Prometheus is running" "Prometheus está corriendo" \
     "./lab.sh addon monitoring" "./lab.sh addon monitoring" \
     sts_ready observability prometheus-kps-kube-prometheus-stack-prometheus
task "ServiceMonitor shop-web exists" "Existe el ServiceMonitor shop-web" \
     "kubectl apply -f level-8/servicemonitor.yaml" "kubectl apply -f level-8/servicemonitor.yaml" \
     exists servicemonitor shop-web -n shop
task "Prometheus scrapes shop-web (target up)" "Prometheus recoge métricas de shop-web (target up)" \
     "Wait a minute or two; check http://localhost:9090/targets and the release=kps label" "Espera uno o dos minutos; mira http://localhost:9090/targets y la label release=kps" \
     prom_query 'up{namespace="shop"}'
task "Rule PodPendingOver2Min is loaded" "La regla PodPendingOver2Min está cargada" \
     "kubectl apply -f level-8/prometheusrule.yaml" "kubectl apply -f level-8/prometheusrule.yaml" \
     bash -c "kubectl --context $CTX get --raw /api/v1/namespaces/observability/services/http:kps-kube-prometheus-stack-prometheus:9090/proxy/api/v1/rules | grep -q PodPendingOver2Min"
finish 8
