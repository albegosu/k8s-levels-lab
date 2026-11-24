# Nivel 5 · Scheduling y nodos

[English](README.md)

## Conceptos

- **Scheduler.** Para un pod sin nodo, **filtra** (hueco de requests suficiente, selectores y afinidad que encajan, taints tolerados, nodo sin cordon) y **puntúa** los que quedan. Si ningún nodo pasa el filtro, el pod queda `Pending` con un evento `FailedScheduling` que explica por qué.
- **Capacity, allocatable y requests.** Allocatable es lo que queda para pods tras la parte del sistema. El scheduler solo mira `allocatable − suma de requests`, nunca el consumo real: un nodo puede estar al 99 % de requests y usar un 40 %.
- **nodeSelector y afinidad** atraen pods a nodos; los **taints** los repelen salvo que el pod tenga la **toleration**. Los DaemonSets toleran casi todos los taints, incluido el del cordon.
- **PriorityClass y preemption.** Un pod de más prioridad que no cabe puede expulsar pods de menos prioridad.
- **Cordon** cierra un nodo a pods nuevos (sigue Ready). **Drain** hace cordon y desaloja todos los pods que no son de DaemonSet con la Eviction API, respetando los PDB. **Uncordon** lo reabre; los pods desalojados no vuelven.
- **PodDisruptionBudget.** Cuántos pods de una app pueden caer a la vez por causas voluntarias (drain, upgrades, consolidación).
- **Karpenter** (no está en kind) crea un nodo a medida para los pods Pending y consolida nodos hasta dejarlos llenos de requests. Ahorra dinero, pero deja poco margen a un pod que tiene que crecer en su propio nodo.

## Mirar los nodos

```bash
kubectl get nodes -L role,karpenter.sh/nodepool
kubectl describe node lab-worker2 | sed -n '/Capacity/,/System Info/p'   # capacity vs allocatable
kubectl describe node lab-worker2 | sed -n '/Allocated resources/,/Events/p'
kubectl top node                                                       # consumo real
```

## Pending por requests

```bash
kubectl create deployment huge --image=registry.k8s.io/pause:3.10 -n sandbox
kubectl set resources deployment huge --requests=memory=64Gi -n sandbox
kubectl get pods -n sandbox
kubectl describe pod -n sandbox -l app=huge | grep -A2 FailedScheduling
kubectl delete deployment huge -n sandbox
```

## El drain (el incidente)

Ten una vista en directo abierta: en Headlamp, Cluster → Nodes → `lab-worker2`, o `k9s --context kind-lab` con `:pods` y `0`.

```bash
./level-5/reproduce-incident.sh
```

Un pod de `log-agent` está `Pending`. Diagnostica antes de tocar nada:

```bash
kubectl describe -n observability $(kubectl get pod -n observability --field-selector=status.phase=Pending -o name)
kubectl describe node lab-worker2 | sed -n '/Allocated resources/,/Events/p'
kubectl top node lab-worker2
```

El nodo está casi al 100 % de requests de memoria, pero el consumo real es bajo. Arréglalo:

```bash
kubectl cordon lab-worker2
kubectl get nodes                                   # SchedulingDisabled, pero Ready
kubectl drain lab-worker2 --ignore-daemonsets --delete-emptydir-data
```

Si dejaste el pod `hello` del nivel 1, el drain se para con `cannot delete Pods that declare no controller`. Un pod sin controlador no volvería a ningún sitio, así que drain no lo borra sin `--force`. Bórralo tú y repite el drain:

```bash
kubectl delete pod hello -n sandbox
kubectl drain lab-worker2 --ignore-daemonsets --delete-emptydir-data
kubectl get pods -A -o wide | grep -E 'app-load|log-agent'
kubectl uncordon lab-worker2
kubectl get pods -A -o wide | grep app-load         # no vuelve a lab-worker2
```

`app-load` se va a `lab-worker`, se libera hueco y el agente nuevo arranca: los DaemonSets toleran el cordon. Los pods de `shop-web` quedan `Pending` hasta el uncordon, porque su `nodeSelector` solo admite el NodePool `default` y su único nodo está cerrado. En EKS, Karpenter crearía un nodo para ellos.

## Overprovisioning (el colchón)

```bash
kubectl delete deploy app-load -n shop
./level-5/reproduce-incident.sh --overprovisioning
kubectl get pods -A -o wide | grep -E 'overprovisioning|log-agent'
kubectl get events -n kube-system --field-selector reason=Preempted
```

Esta vez el agente nuevo expulsa al pod de relleno y arranca solo; el relleno queda `Pending`. En EKS, Karpenter vería ese Pending y añadiría un nodo antes de que haga falta de verdad.

Otras formas de evitarlo: una PriorityClass alta para los DaemonSets de plataforma (`platform-priority.yaml`), un rolling update del DaemonSet con `maxSurge: 0` (sin convivencia, unos segundos sin agente) y requests ajustados.

## PodDisruptionBudget

```bash
kubectl apply -f level-2/web.yaml -f level-5/pdb.yaml
kubectl get pods -n shop -o wide -l app.kubernetes.io/component=web
kubectl drain lab-worker2 --ignore-daemonsets --delete-emptydir-data --timeout=30s   # se queda esperando
kubectl get pdb -n shop                             # ALLOWED DISRUPTIONS 0
kubectl uncordon lab-worker2
kubectl delete -f level-5/pdb.yaml
```

## Limpiar

```bash
kubectl delete deploy app-load -n shop --ignore-not-found
kubectl delete -f level-5/overprovisioning.yaml --ignore-not-found
```

## Corrige tu trabajo

```bash
LAB_LANG=es ./lab.sh check 5
```

Comprueba que el incidente ha terminado y el clúster queda limpio: sin cordon, todos los agentes listos y nada en Pending. Lánzalo después de limpiar.

## Comprueba que lo has entendido

- [ ] ¿Por qué un nodo con memoria real libre puede rechazar un pod?
- [ ] Cordon, drain y uncordon: ¿qué pasa con los pods de DaemonSet en cada uno?
- [ ] ¿Por qué Karpenter no podía arreglar el pod `log-agent` en Pending?
- [ ] ¿Qué compruebas antes de hacer un drain?
