# Level 9 · Operations

[Español](README.es.md)

## A diagnosis method

Go from the outside in, and read events before touching anything:

1. **Right cluster?** `kubectl config current-context`.
2. **What does GitOps say?** `OutOfSync` = Git and cluster differ; `Degraded` = something does not start.
3. **Pod state?** `kubectl get pods -n <ns> -o wide`.
4. **Events?** `kubectl describe pod` and `kubectl get events --sort-by=.lastTimestamp`. The answer is almost always here.
5. **Pending:** read `FailedScheduling`; check node requests and whether a node is being created.
6. **CrashLoopBackOff:** `kubectl logs --previous`; check for a missing Secret.
7. **Running but not answering:** Service endpoints, HTTPRoute status, DNS.

| Symptom | First suspect |
| --- | --- |
| `Pending` | No room in requests, affinity or selector, volume zone |
| `ImagePullBackOff` | Wrong tag, registry permissions, architecture |
| `CrashLoopBackOff` | App fails on start-up, missing config |
| `CreateContainerConfigError` | Missing Secret or ConfigMap |
| `OOMKilled` | Memory limit too low |
| 503 from outside | No ready pods, wrong Service selector |

## Five faults

```bash
kubectl apply -f level-9/faults.yaml
kubectl get pods -n faults
```

There are five faults: `api`, `worker`, `web`, `reports` and `queue`. For each one, without opening the YAML:

1. Name the symptom (pod or Service state).
2. Find the cause with `describe`, `logs`, `events` or `get endpointslices`.
3. Say which level the concept belongs to and how you would fix it.

```bash
kubectl get events -n faults --sort-by=.lastTimestamp
kubectl describe pod -n faults -l app=<name>
kubectl logs -n faults deploy/<name> --previous
kubectl get svc,endpointslices -n faults
```

## Check your work

```bash
./lab.sh check 9
```

Mission: fix the five faults in place (edit, patch or create what is missing) without deleting the Deployments. The check passes when all five run.

Then compare with [solutions.md](solutions.md).

```bash
kubectl delete namespace faults
```
