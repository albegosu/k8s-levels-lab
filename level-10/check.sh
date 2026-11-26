#!/usr/bin/env bash
# Level 10 check: a working inference platform on CPU, with tenants, limits, fallback and metrics.
source "$(dirname "$0")/../checks/lib.sh"
source "$(dirname "$0")/lib.sh"

chat_status() { # <key>: HTTP status of one small chat request through the gateway
  echo '{"model": "chat", "max_tokens": 5, "messages": [{"role": "user", "content": "hi"}]}' |
    gw POST /v1/chat/completions "$1" 2>/dev/null | head -1
}
model_answers() {
  echo '{"model": "qwen2.5-0.5b", "max_tokens": 5, "messages": [{"role": "user", "content": "hi"}]}' > /tmp/lab10-chat.json
  k create --raw /api/v1/namespaces/inference/services/http:qwen:8080/proxy/v1/chat/completions -f /tmp/lab10-chat.json | grep -q '"choices"'
}
team_a_ok() { [[ "$(chat_status "$(tenant_key team-a)")" == 200 ]]; }
team_b_over_budget() { [[ "$(chat_status "$(tenant_key team-b)")" == 422 ]]; }
fallback_allowed() {
  gw GET /key/info "$(tenant_key team-a)" | tail -n +2 |
    python3 -c 'import sys, json; m = json.load(sys.stdin)["info"]["models"]; sys.exit(0 if not m or "chat-backup" in m else 1)'
}
fallback_used() {
  gw GET /metrics "$(master_key)" | awk '/^litellm_deployment_successful_fallbacks_total/ { s += $NF } END { exit !(s > 0) }'
}

header "Level 10 · Inference platform" "Nivel 10 · Plataforma de inferencia"
task "Model server qwen is ready" "El servidor de modelos qwen está listo" \
     "kubectl apply -f level-10/model.yaml; kubectl logs -n inference deploy/qwen" "kubectl apply -f level-10/model.yaml; kubectl logs -n inference deploy/qwen" \
     deploy_ready inference qwen
task "qwen answers on its Service" "qwen responde en su Service" \
     "kubectl port-forward svc/qwen -n inference 8080; curl localhost:8080/v1/models" "kubectl port-forward svc/qwen -n inference 8080; curl localhost:8080/v1/models" \
     model_answers
task "Postgres and LiteLLM are ready" "Postgres y LiteLLM están listos" \
     "./level-10/secrets.sh; kubectl apply -f level-10/postgres.yaml -f level-10/litellm.yaml; kubectl get pods -n inference" "./level-10/secrets.sh; kubectl apply -f level-10/postgres.yaml -f level-10/litellm.yaml; kubectl get pods -n inference" \
     bash -c "$(declare -f k jp deploy_ready sts_ready); CTX=$CTX; sts_ready inference postgres && deploy_ready inference litellm"
task "Tenants team-a and team-b exist" "Existen los tenants team-a y team-b" \
     "./level-10/tenants.sh" "./level-10/tenants.sh" \
     exists secret tenant-keys -n inference
task "team-a gets answers through the gateway" "team-a obtiene respuestas a través del gateway" \
     "./level-10/load.sh 1 1 team-a; read the error it prints" "./level-10/load.sh 1 1 team-a; lee el error que imprime" \
     team_a_ok
task "team-b has spent its budget (gateway answers 422)" "team-b ha gastado su presupuesto (el gateway responde 422)" \
     "./level-10/load.sh 1 3 team-b, wait a minute for spend to be recorded, try again" "./level-10/load.sh 1 3 team-b, espera un minuto a que se registre el gasto y repite" \
     team_b_over_budget
task "team-a's key may use the fallback model" "La clave de team-a puede usar el modelo de fallback" \
     "Scale qwen to 0 and read the gateway error: why is the fallback skipped? (README, task 5)" "Escala qwen a 0 y lee el error del gateway: ¿por qué se salta el fallback? (README, tarea 5)" \
     fallback_allowed
task "A request was served by the fallback" "Una petición se sirvió por el fallback" \
     "kubectl scale deploy/qwen -n inference --replicas=0; ./level-10/load.sh 1 1; then scale back to 1" "kubectl scale deploy/qwen -n inference --replicas=0; ./level-10/load.sh 1 1; y vuelve a escalar a 1" \
     fallback_used
task "Prometheus scrapes LiteLLM and qwen" "Prometheus recoge métricas de LiteLLM y qwen" \
     "./lab.sh addon monitoring; kubectl apply -f level-10/monitoring.yaml; wait a minute" "./lab.sh addon monitoring; kubectl apply -f level-10/monitoring.yaml; espera un minuto" \
     bash -c "$(declare -f k exists prom_query); CTX=$CTX; exists servicemonitor litellm -n inference && prom_query 'up{namespace=\"inference\",service=\"litellm\"}' && prom_query 'up{namespace=\"inference\",service=\"qwen\"}'"
task "Inference alerts are loaded" "Las alertas de inferencia están cargadas" \
     "kubectl apply -f level-10/monitoring.yaml" "kubectl apply -f level-10/monitoring.yaml" \
     bash -c "kubectl --context $CTX get prometheusrule inference-lab -n inference >/dev/null && kubectl --context $CTX get --raw /api/v1/namespaces/observability/services/http:kps-kube-prometheus-stack-prometheus:9090/proxy/api/v1/rules | grep -q GatewayLatencyHigh"
finish 10
