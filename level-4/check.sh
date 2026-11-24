#!/usr/bin/env bash
# Level 4 check: the secret travels from the store to the pod, and RBAC is least privilege.
source "$(dirname "$0")/../checks/lib.sh"
header "Level 4 · Config, secrets and identity" "Nivel 4 · Configuración, secretos e identidad"
task "SecretStore shop is valid" "El SecretStore shop es válido" \
     "kubectl apply -f level-4/secret-store.yaml; kubectl describe secretstore shop -n shop" "kubectl apply -f level-4/secret-store.yaml; kubectl describe secretstore shop -n shop" \
     condition secretstore shop shop Ready
task "ExternalSecret shop-app is synced" "El ExternalSecret shop-app está sincronizado" \
     "kubectl apply -f level-4/external-secret.yaml; kubectl describe externalsecret shop-app -n shop" "kubectl apply -f level-4/external-secret.yaml; kubectl describe externalsecret shop-app -n shop" \
     condition externalsecret shop shop-app Ready
task "Secret shop-app has DATABASE_URL" "El Secret shop-app tiene DATABASE_URL" \
     "External Secrets creates it; check the remoteRef property names" "Lo crea External Secrets; revisa los property del remoteRef" \
     test -n "$(jp secret shop-app -n shop -o jsonpath='{.data.DATABASE_URL}')"
task "Deployment shop-worker is running" "El Deployment shop-worker está corriendo" \
     "kubectl apply -f level-4/worker.yaml; CreateContainerConfigError means the Secret is missing" "kubectl apply -f level-4/worker.yaml; CreateContainerConfigError = falta el Secret" \
     deploy_ready shop shop-worker
task "ServiceAccount reader can list pods in shop" "El ServiceAccount reader puede listar pods en shop" \
     "kubectl apply -f level-4/rbac.yaml" "kubectl apply -f level-4/rbac.yaml" \
     can_i list pods -n shop --as=system:serviceaccount:shop:reader
task "reader cannot read Secrets (least privilege)" "reader no puede leer Secrets (mínimo privilegio)" \
     "The Role pod-reader must not include secrets" "El Role pod-reader no debe incluir secrets" \
     cannot_i get secrets -n shop --as=system:serviceaccount:shop:reader
finish 4
