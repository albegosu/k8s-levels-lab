#!/usr/bin/env bash
# Level 3 check: Service with endpoints, HTTPRoute accepted, a real request through Envoy.
source "$(dirname "$0")/../checks/lib.sh"
header "Level 3 · Networking" "Nivel 3 · Red"
task "Service shop-web has ready endpoints" "El Service shop-web tiene endpoints listos" \
     "kubectl apply -f level-3/service.yaml and scale shop-web back to 2 replicas" "kubectl apply -f level-3/service.yaml y vuelve a escalar shop-web a 2 réplicas" \
     endpoints_ready shop shop-web
task "HTTPRoute shop-web is accepted by the Gateway" "La HTTPRoute shop-web está aceptada por el Gateway" \
     "kubectl apply -f level-3/httproute.yaml; read .status.parents[].conditions" "kubectl apply -f level-3/httproute.yaml; lee .status.parents[].conditions" \
     test "$(jp httproute shop-web -n shop -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}')" = True
task "HTTPRoute shop-web resolves its backend" "La HTTPRoute shop-web resuelve su backend" \
     "ResolvedRefs=False usually means the Service name or port is wrong" "ResolvedRefs=False suele ser nombre o puerto del Service mal" \
     test "$(jp httproute shop-web -n shop -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')" = True
task "No NetworkPolicy left blocking shop" "No queda ninguna NetworkPolicy bloqueando shop" \
     "kubectl delete -f level-3/networkpolicy.yaml" "kubectl delete -f level-3/networkpolicy.yaml" \
     test -z "$(jp networkpolicy -n shop -o name)"
ENVOY=$(jp svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=internal -o jsonpath='{.items[0].metadata.name}')
task "A request to shop.lab.local through Envoy answers 200" "Una petición a shop.lab.local a través de Envoy responde 200" \
     "Check the Gateway (./lab.sh addon gateway) and that shop-web pods are Ready" "Revisa el Gateway (./lab.sh addon gateway) y que los pods de shop-web estén Ready" \
     k run lab-check-http --rm -i --quiet --restart=Never -n default --image=busybox:1.36 -- \
       wget -qO /dev/null -T 5 --header "Host: shop.lab.local" "http://${ENVOY:-missing}.envoy-gateway-system"
finish 3
