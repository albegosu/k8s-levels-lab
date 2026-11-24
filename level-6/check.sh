#!/usr/bin/env bash
# Level 6 check: Argo CD deploys from Git, the CI-style bump landed and selfHeal held.
source "$(dirname "$0")/../checks/lib.sh"
header "Level 6 · Helm and GitOps" "Nivel 6 · Helm y GitOps"
task "Argo CD is installed" "Argo CD está instalado" \
     "./lab.sh addon argocd" "./lab.sh addon argocd" \
     deploy_ready argocd argocd-server
task "Application shop-lab exists" "Existe la Application shop-lab" \
     "./level-6/gitops.sh up" "./level-6/gitops.sh up" \
     exists application shop-lab -n argocd
task "shop-lab is Synced" "shop-lab está Synced" \
     "Refresh: kubectl annotate application shop-lab -n argocd argocd.argoproj.io/refresh=normal --overwrite" "Refresca: kubectl annotate application shop-lab -n argocd argocd.argoproj.io/refresh=normal --overwrite" \
     test "$(jp application shop-lab -n argocd -o jsonpath='{.status.sync.status}')" = Synced
task "shop-lab is Healthy" "shop-lab está Healthy" \
     "kubectl describe application shop-lab -n argocd; look for Degraded resources" "kubectl describe application shop-lab -n argocd; busca recursos Degraded" \
     test "$(jp application shop-lab -n argocd -o jsonpath='{.status.health.status}')" = Healthy
task "The CI-style bump is live: shop-lab runs 6.7.1" "El bump de la CI está desplegado: shop-lab usa 6.7.1" \
     "./level-6/gitops.sh bump 6.7.1, then refresh the Application" "./level-6/gitops.sh bump 6.7.1 y refresca la Application" \
     image_tag_is shop-lab shop-web 6.7.1
task "selfHeal kept the replicas from Git (2)" "selfHeal mantuvo las réplicas de Git (2)" \
     "Change replicas in Git, not with kubectl scale" "Cambia las réplicas en Git, no con kubectl scale" \
     test "$(jp deploy shop-web -n shop-lab -o jsonpath='{.spec.replicas}')" = 2
finish 6
