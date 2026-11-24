# Nivel 6 · Helm y GitOps

[English](README.md)

## Conceptos

- **Helm** genera YAML a partir de plantillas. Un **chart** tiene `Chart.yaml`, `values.yaml` (los parámetros: tag de imagen, réplicas, recursos, host) y `templates/`. `helm template` pinta el YAML final sin instalar nada.
- **Argo CD** vigila Git y hace que el clúster coincida. Cada **Application** tiene un estado de **sync** (`Synced` / `OutOfSync`) y otro de **health** (`Healthy`, `Progressing`, `Degraded`, `Missing`).
- Un **ApplicationSet** genera una Application por directorio: añadir una app es añadir `apps/<nombre>/` al repo.
- Un despliegue típico: la CI construye y sube la imagen y hace un commit con el tag nuevo en el repo GitOps; Argo CD sincroniza y el Deployment hace el rolling update. **Rollback = revertir ese commit**, no `kubectl rollout undo`.
- Con `selfHeal: true`, Argo CD deshace al momento los cambios manuales. Sin él, la app queda `OutOfSync` hasta el siguiente sync.

## Helm

```bash
helm template shop level-6/shop | less
helm template shop level-6/shop --set web.replicas=5 | grep replicas
helm install shop level-6/shop -n helm-lab --create-namespace
helm list -A
helm upgrade shop level-6/shop -n helm-lab --set image.tag=6.7.1
helm history shop -n helm-lab
helm rollback shop 1 -n helm-lab
helm uninstall shop -n helm-lab
```

## Argo CD con un repo GitOps local

`gitops.sh` crea un repo Git en `.gitops/`, lo sirve con `git daemon` en el puerto 9418 y aplica un ApplicationSet que apunta a él a través de `host.docker.internal`.

```bash
./lab.sh addon argocd
./level-6/gitops.sh up
kubectl get applicationset,application -n argocd
kubectl get pods -n shop-lab -w
```

Abre la UI:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d; echo
kubectl port-forward svc/argocd-server -n argocd 8443:443
```

Entra en `https://localhost:8443` con `admin` y esa contraseña.

## Un despliegue como el de la CI

```bash
./level-6/gitops.sh bump 6.7.1      # el mismo commit que hace un pipeline de CI
kubectl annotate application shop-lab -n argocd argocd.argoproj.io/refresh=normal --overwrite
kubectl get application shop-lab -n argocd -w     # OutOfSync → Synced
kubectl get pods -n shop-lab -o jsonpath='{.items[*].spec.containers[0].image}'; echo
```

Sin la anotación, Argo CD consulta Git cada 3 minutos (o pulsa Refresh en la UI).

## Ver a Argo CD deshacer un cambio manual

```bash
kubectl scale deployment shop-web -n shop-lab --replicas=5
kubectl get pods -n shop-lab -w     # selfHeal lo devuelve a 2
```

Rollback de verdad: `git -C .gitops/platform-gitops-lab revert --no-edit HEAD`.

## Limpiar

```bash
./level-6/gitops.sh down
```

## Comprueba que lo has entendido

- [ ] ¿Qué commit reviertes para volver a la versión anterior de una app?
- [ ] ¿Por qué no dura un `kubectl edit` en un clúster con GitOps?
- [ ] ¿Qué pasa si creas `apps/nueva` en el repo GitOps?
- [ ] Distingue `OutOfSync` de `Degraded`.
