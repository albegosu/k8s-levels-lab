# Level 5 · Scheduling and nodes

[Español](README.es.md)

## Concepts

- **Scheduler.** For a pod without a node it **filters** (enough free requests, matching selectors and affinity, tolerated taints, node not cordoned) and **scores** the rest. If no node passes, the pod stays `Pending` with a `FailedScheduling` event that says why.
- **Capacity, allocatable, requests.** Allocatable is what is left for pods after the system's share. The scheduler only looks at `allocatable − sum of requests`, never at real usage: a node can be 99 % full of requests and 40 % used.
- **nodeSelector / affinity** pull pods to nodes; **taints** push them away unless the pod has a **toleration**. DaemonSets tolerate almost every taint, including cordon.
- **PriorityClass and preemption.** A higher-priority pod that does not fit can evict lower-priority pods.
- **Cordon** closes a node to new pods (it stays Ready). **Drain** cordons and evicts every non-DaemonSet pod through the Eviction API, respecting PDBs. **Uncordon** reopens it; evicted pods do not come back.
- **PodDisruptionBudget.** How many pods of an app may go down at once for voluntary reasons (drain, upgrades, consolidation).
- **Karpenter** (not on kind) creates a right-sized node for Pending pods and consolidates nodes until they are full of requests. That saves money but leaves little room for a pod that must grow on its own node.

## Look at the nodes

```bash
kubectl get nodes -L role,karpenter.sh/nodepool
kubectl describe node lab-worker2 | sed -n '/Capacity/,/System Info/p'   # capacity vs allocatable
kubectl describe node lab-worker2 | sed -n '/Allocated resources/,/Events/p'
kubectl top node                                                       # real usage
```

## Pending because of requests

```bash
kubectl create deployment huge --image=registry.k8s.io/pause:3.10 -n sandbox
kubectl set resources deployment huge --requests=memory=64Gi -n sandbox
kubectl get pods -n sandbox
kubectl describe pod -n sandbox -l app=huge | grep -A2 FailedScheduling
kubectl delete deployment huge -n sandbox
```

## The drain (the incident)

Keep a live view open: in Headlamp, Cluster → Nodes → `lab-worker2`, or `k9s --context kind-lab` with `:pods` and `0`.

```bash
./level-5/reproduce-incident.sh
```

One `log-agent` pod is `Pending`. Diagnose before touching anything:

```bash
kubectl describe -n observability $(kubectl get pod -n observability --field-selector=status.phase=Pending -o name)
kubectl describe node lab-worker2 | sed -n '/Allocated resources/,/Events/p'
kubectl top node lab-worker2
```

The node is almost 100 % full of memory requests while real usage is low. Fix it:

```bash
kubectl cordon lab-worker2
kubectl get nodes                                   # SchedulingDisabled, still Ready
kubectl drain lab-worker2 --ignore-daemonsets --delete-emptydir-data
```

If you kept the `hello` pod from level 1, the drain stops with `cannot delete Pods that declare no controller`. A pod without a controller would not come back anywhere, so drain refuses to delete it without `--force`. Delete it yourself and drain again:

```bash
kubectl delete pod hello -n sandbox
kubectl drain lab-worker2 --ignore-daemonsets --delete-emptydir-data
kubectl get pods -A -o wide | grep -E 'app-load|log-agent'
kubectl uncordon lab-worker2
kubectl get pods -A -o wide | grep app-load         # it does not return to lab-worker2
```

`app-load` moves to `lab-worker`, room is freed and the new agent starts: DaemonSets tolerate the cordon. The `shop-web` pods stay `Pending` until the uncordon, because their `nodeSelector` only accepts the `default` NodePool and its only node is closed. On EKS, Karpenter would create a node for them.

## Overprovisioning

```bash
kubectl delete deploy app-load -n shop
./level-5/reproduce-incident.sh --overprovisioning
kubectl get pods -A -o wide | grep -E 'overprovisioning|log-agent'
kubectl get events -n kube-system --field-selector reason=Preempted
```

This time the new agent preempts the placeholder and starts on its own; the placeholder goes `Pending`. On EKS, Karpenter would see that Pending pod and add a node for it, ahead of real demand.

Other ways to prevent it: a high PriorityClass for platform DaemonSets (`platform-priority.yaml`), a DaemonSet rolling update with `maxSurge: 0` (no co-existence, a few seconds without agent), and right-sized requests.

## PodDisruptionBudget

```bash
kubectl apply -f level-2/web.yaml -f level-5/pdb.yaml
kubectl get pods -n shop -o wide -l app.kubernetes.io/component=web
kubectl drain lab-worker2 --ignore-daemonsets --delete-emptydir-data --timeout=30s   # keeps waiting
kubectl get pdb -n shop                             # ALLOWED DISRUPTIONS 0
kubectl uncordon lab-worker2
kubectl delete -f level-5/pdb.yaml
```

## Clean up

```bash
kubectl delete deploy app-load -n shop --ignore-not-found
kubectl delete -f level-5/overprovisioning.yaml --ignore-not-found
```

## Check your work

```bash
./lab.sh check 5
```

It checks that the incident is over and the cluster is clean: no cordon, every agent ready, nothing Pending. Run it after the clean-up.

## Check yourself

- [ ] Why can a node with free real memory reject a pod?
- [ ] Cordon, drain, uncordon: what happens to DaemonSet pods in each one?
- [ ] Why could Karpenter not fix the Pending `log-agent` pod?
- [ ] What do you check before draining a node?
