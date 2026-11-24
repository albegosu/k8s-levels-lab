# Level 2 · Workloads

[Español](README.es.md)

## Concepts

You never create pods by hand: you create a **controller** that creates and keeps them.

| Controller | Guarantees | File |
| --- | --- | --- |
| Deployment | N identical, interchangeable replicas | `web.yaml` |
| StatefulSet | Replicas with a fixed name (`-0`, `-1`) and their own disk | `redis.yaml` |
| DaemonSet | One pod on every matching node | `log-agent.yaml` |
| Job | Run until it succeeds | `job.yaml` |

- A **Deployment** creates a **ReplicaSet**, which counts pods and creates or deletes them. Every change to the pod template creates a new ReplicaSet.
- **Requests** are what a container reserves (the scheduler uses them). **Limits** are the ceiling: over the CPU limit it is throttled, over the memory limit it is killed (`OOMKilled`).
- **readinessProbe**: can it take traffic? If it fails, the pod is removed from the Service but not restarted. **livenessProbe**: is it stuck? If it fails, the kubelet restarts the container.
- **Rolling update**: the new version starts, waits to be ready, then an old pod is removed. Old and new pods live side by side for a while and both need room.
- A **DaemonSet** pod belongs to its node. It cannot go elsewhere: if its node is full, it stays Pending even if other nodes have room.

## Deployment and ReplicaSet

```bash
kubectl apply -f level-2/web.yaml
kubectl get deploy,rs,pods -n shop -o wide
kubectl delete pod -n shop -l app.kubernetes.io/component=web --wait=false
kubectl get pods -n shop -w          # they come back: the ReplicaSet replaces them
```

## Rolling update

```bash
kubectl set image deployment/shop-web web=ghcr.io/stefanprodan/podinfo:6.7.1 -n shop
kubectl rollout status deployment/shop-web -n shop
kubectl get rs -n shop               # two ReplicaSets: the old one at 0
kubectl rollout history deployment/shop-web -n shop
kubectl set image deployment/shop-web web=ghcr.io/stefanprodan/podinfo:does-not-exist -n shop
kubectl get pods -n shop             # the new pod fails; the old ones keep serving
kubectl rollout undo deployment/shop-web -n shop   # fine on kind; with GitOps, revert in Git
```

## Probes

```bash
POD=$(kubectl get pod -n shop -l app.kubernetes.io/component=web -o name | head -1)
kubectl exec -n shop $POD -- wget -qO- --post-data='' localhost:9898/readyz/disable
sleep 20                             # readiness must fail 3 times in a row
kubectl get pods -n shop             # 0/1 Running: out of the Service, not restarted
kubectl exec -n shop $POD -- wget -qO- --post-data='' localhost:9898/readyz/enable
```

## StatefulSet, DaemonSet and Job

```bash
kubectl apply -f level-2/redis.yaml
kubectl get pods,pvc -n shop -w      # redis-0 starts before redis-1
kubectl delete pod redis-0 -n shop   # comes back with the same name and the same PVC
kubectl apply -f level-2/log-agent.yaml
kubectl get pods -n observability -o wide   # one per worker
kubectl apply -f level-2/job.yaml
kubectl get jobs,pods -n shop
kubectl logs job/db-migrate -n shop
```

## Check your work

```bash
./lab.sh check 2
```

It checks that the four controllers end healthy and that `shop-web` runs podinfo 6.7.1.

## Check yourself

- [ ] Explain the Deployment → ReplicaSet → Pod chain.
- [ ] Why does `log-agent` have no pod on `lab-control-plane`?
- [ ] What happens to traffic when readiness fails, and when liveness fails?
