# Level 1 · Fundamentals

[Español](README.es.md)

## Concepts

- **Image and container.** An image is a sealed package with an app and everything it needs; a container is that image running. Images live in a registry and the **tag** names the version.
- **Cluster.** A **control plane** (API server, etcd, scheduler, controllers) that decides, and **nodes** that run containers through the **kubelet**.
- **Desired state.** You don't say "start two containers", you say "I want two". Controllers keep comparing what exists with what you want and fix the difference.
- **Pod.** The smallest unit Kubernetes schedules: one or more containers sharing network and disk. Ephemeral: a dead pod is replaced by a new one with another name and IP, never resurrected. It runs on one node and never moves.
- **Namespace.** A logical folder that separates names, permissions and quotas.
- **Manifest.** YAML with `apiVersion`, `kind`, `metadata`, `spec` (what you want); Kubernetes adds `status` (what there is). Comparing `spec` and `status` is the first step of any investigation.

## Exercises

```bash
kubectl config current-context          # must say kind-lab
kubectl get nodes -o wide -L role,karpenter.sh/nodepool
kubectl create namespace sandbox
kubectl apply -f level-1/pod.yaml
kubectl get pods -n sandbox -w           # Ctrl+C once it is Running
kubectl describe pod hello -n sandbox    # read the Events at the end
kubectl get pod hello -n sandbox -o yaml # compare spec with status
kubectl logs hello -n sandbox
kubectl delete pod hello -n sandbox
kubectl get pods -n sandbox              # it does not come back: nobody watches it
kubectl apply -f level-1/pod-broken.yaml
kubectl describe pod broken -n sandbox   # ImagePullBackOff and its cause
kubectl delete -f level-1/pod-broken.yaml
kubectl explain pod.spec.containers.image
```

| Command | Use |
| --- | --- |
| `kubectl get` | List objects and their state |
| `kubectl describe` | Details and recent events: first stop when something fails |
| `kubectl logs` | Container output; `--previous` for the one that died |
| `kubectl get events --sort-by=.lastTimestamp` | What happened in a namespace |
| `kubectl get -o yaml` | The whole object, `spec` and `status` |

## Check yourself

- [ ] Why does a pod deleted by hand not come back?
- [ ] On which node did `hello` land, and why not on `lab-control-plane`? Hint: `kubectl describe node lab-control-plane | grep Taints`.
- [ ] Where do you read why a pod does not start?
