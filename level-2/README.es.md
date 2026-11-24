# Nivel 2 · Workloads

[English](README.md)

## Conceptos

Nunca creas pods a mano: creas un **controlador** que los crea y los mantiene.

| Controlador | Qué garantiza | Fichero |
| --- | --- | --- |
| Deployment | N réplicas iguales e intercambiables | `web.yaml` |
| StatefulSet | Réplicas con nombre fijo (`-0`, `-1`) y disco propio | `redis.yaml` |
| DaemonSet | Un pod en cada nodo que cumpla sus condiciones | `log-agent.yaml` |
| Job | Ejecutar hasta terminar con éxito | `job.yaml` |

- Un **Deployment** crea un **ReplicaSet**, que cuenta pods y crea o borra los que falten o sobren. Cada cambio en la plantilla del pod crea un ReplicaSet nuevo.
- Los **requests** son lo que reserva un contenedor (el scheduler los usa). Los **limits** son el techo: si pasa el de CPU se le frena; si pasa el de memoria se le mata (`OOMKilled`).
- **readinessProbe**: ¿puede recibir tráfico? Si falla, el pod sale del Service pero no se reinicia. **livenessProbe**: ¿está colgado? Si falla, el kubelet reinicia el contenedor.
- **Rolling update**: arranca la versión nueva, espera a que esté lista y quita un pod viejo. Durante un rato conviven pods viejos y nuevos, y hace falta hueco para todos.
- Un pod de **DaemonSet** pertenece a su nodo. No puede irse a otro: si su nodo está lleno, se queda Pending aunque otros nodos tengan hueco.

## Deployment y ReplicaSet

```bash
kubectl apply -f level-2/web.yaml
kubectl get deploy,rs,pods -n shop -o wide
kubectl delete pod -n shop -l app.kubernetes.io/component=web --wait=false
kubectl get pods -n shop -w          # vuelven solos: el ReplicaSet los repone
```

## Rolling update

```bash
kubectl set image deployment/shop-web web=ghcr.io/stefanprodan/podinfo:6.7.1 -n shop
kubectl rollout status deployment/shop-web -n shop
kubectl get rs -n shop               # dos ReplicaSets: el viejo a 0
kubectl rollout history deployment/shop-web -n shop
kubectl set image deployment/shop-web web=ghcr.io/stefanprodan/podinfo:does-not-exist -n shop
kubectl get pods -n shop             # el nuevo falla; los viejos siguen sirviendo
kubectl rollout undo deployment/shop-web -n shop   # en kind sí; con GitOps, revert en Git
```

## Probes

```bash
POD=$(kubectl get pod -n shop -l app.kubernetes.io/component=web -o name | head -1)
kubectl exec -n shop $POD -- wget -qO- --post-data='' localhost:9898/readyz/disable
sleep 20                             # la readiness tiene que fallar 3 veces seguidas
kubectl get pods -n shop             # 0/1 Running: fuera del Service, sin reiniciar
kubectl exec -n shop $POD -- wget -qO- --post-data='' localhost:9898/readyz/enable
```

## StatefulSet, DaemonSet y Job

```bash
kubectl apply -f level-2/redis.yaml
kubectl get pods,pvc -n shop -w      # redis-0 arranca antes que redis-1
kubectl delete pod redis-0 -n shop   # vuelve con el mismo nombre y el mismo PVC
kubectl apply -f level-2/log-agent.yaml
kubectl get pods -n observability -o wide   # uno por worker
kubectl apply -f level-2/job.yaml
kubectl get jobs,pods -n shop
kubectl logs job/db-migrate -n shop
```

## Corrige tu trabajo

```bash
LAB_LANG=es ./lab.sh check 2
```

Comprueba que los cuatro controladores acaban sanos y que `shop-web` usa podinfo 6.7.1.

## Comprueba que lo has entendido

- [ ] Explica la cadena Deployment → ReplicaSet → Pod.
- [ ] ¿Por qué `log-agent` no tiene pod en `lab-control-plane`?
- [ ] ¿Qué pasa con el tráfico si falla la readiness, y si falla la liveness?
