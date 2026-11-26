# CKAD track

[Español](README.es.md)

Twelve timed drills for the **Certified Kubernetes Application Developer** exam (curriculum for Kubernetes v1.37). They cover what the CKAD asks and levels 1–9 do not. Each drill runs in its own namespace and is graded like a level.

```bash
./lab.sh drill 1          # creates ckad-1, loads any starting manifests, starts the clock
./lab.sh drill 1 check    # grades it and prints the time you took
```

The exam gives you 2 hours for roughly 15–20 tasks, about 6–8 minutes each. Work towards the target times below, using imperative commands first and YAML only where they fall short.

## Exam domains and where to practise them

| Domain | Weight | Lab levels | Drills |
| --- | --- | --- | --- |
| Application Design and Build | 20 % | 2 (workloads), 7 (volumes) | 1 CronJob, 2 init + sidecar, 12 build an image |
| Application Deployment | 20 % | 2 (rolling updates), 6 (Helm) | 6 Kustomize, 7 Helm, 8 canary |
| Application Observability and Maintenance | 15 % | 8 (probes, metrics), 9 (diagnosis) | 10 fix a broken app |
| Application Environment, Configuration and Security | 25 % | 4 (ConfigMap, Secret, RBAC), 5 (requests, limits) | 3 SecurityContext, 4 quotas, 9 RBAC, 11 CRD |
| Services and Networking | 20 % | 3 (Service, NetworkPolicy) | 5 Ingress |

**Ingress, not Gateway API.** Level 3 uses Gateway API, which is where platforms are heading. The CKAD still asks for `Ingress` objects, so drill 5 is about writing them. There is no Ingress controller in the lab: the drill grades the object, not the traffic.

## Drills

| # | Drill | Target | Task |
| --- | --- | --- | --- |
| <a id="drill-1"></a>1 | CronJob | 4 min | CronJob `backup` (busybox, runs `date`) every 5 minutes. Never two at once. Keep 2 successful and 1 failed job. Kill a job after 60 s |
| <a id="drill-2"></a>2 | Init container + native sidecar | 8 min | Pod `web` (nginx). An init container `init` writes `index.html` into a shared `emptyDir`. A native sidecar `logs` (init container with `restartPolicy: Always`) tails the nginx access log. Pod Ready |
| <a id="drill-3"></a>3 | SecurityContext | 6 min | Pod `api` (busybox, `sleep 3600`) as user 1000, `runAsNonRoot`, read-only root filesystem, drop ALL capabilities, no privilege escalation. It must be Running |
| <a id="drill-4"></a>4 | ResourceQuota + LimitRange | 6 min | Quota `team`: 2 CPU, 2Gi, 10 pods (as limits). LimitRange `defaults`: 250m / 256Mi per container. Deployment `worker`, 3 replicas, no resources in its spec, all running |
| <a id="drill-5"></a>5 | Ingress | 5 min | Deployment and Service `web` (nginx, port 80). Ingress `shop`, class `nginx`: `shop.ckad.local/` → `web:80`, `/api` (Prefix) → `api:8080` |
| <a id="drill-6"></a>6 | Kustomize | 6 min | Finish `ckad/kustomize/overlays/prod`: 3 replicas, label `env=prod` on everything, image `nginx:1.27-alpine`. Apply with `kubectl apply -k` |
| <a id="drill-7"></a>7 | Helm | 5 min | Install chart `podinfo/podinfo` as release `web`, then upgrade it to 2 replicas through values |
| <a id="drill-8"></a>8 | Canary | 6 min | Starting manifests are loaded. Make Service `shop` send 20 % of traffic to `shop-v2`: 4 pods of v1, 1 of v2, 5 endpoints |
| <a id="drill-9"></a>9 | ServiceAccount + RBAC | 6 min | SA `reader` that can get, list and watch pods in the namespace, and nothing else. Pod `probe` runs as `reader` without an auto-mounted token |
| <a id="drill-10"></a>10 | Fix a broken app | 10 min | Deployment `broken` is loaded with three faults. Make every replica available, with a readiness probe on `/healthz:8080`. Diagnose from `kubectl`, not from the file |
| <a id="drill-11"></a>11 | CRD | 6 min | `ckad/crd/backup-crd.yaml` does not apply. Fix it, then create Backup `nightly` with `schedule: "0 2 * * *"` |
| <a id="drill-12"></a>12 | Build an image | 8 min | Build `ckad/image` as `ckad/hello:v1`, load it into kind, run Pod `hello` with `imagePullPolicy: Never` and env `GREETING` from ConfigMap `greeting` |

## Find it in the docs, do not memorise it

The exam is open book, within limits: in the exam browser you may use **[kubernetes.io/docs](https://kubernetes.io/docs/)**, the **[Kubernetes blog](https://kubernetes.io/blog/)** and **[helm.sh/docs](https://helm.sh/docs/)** ([Linux Foundation: resources allowed](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed)). Nobody remembers every field of a CronJob or a NetworkPolicy. What passes the exam is knowing **which page has the example to copy**, and the two offline sources that are faster than any page:

1. **`kubectl <verb> <kind> -h`**: the examples at the top of the help are ready to adapt. `k create ingress -h`, `k create cronjob -h` and `k create role -h` write most of drills 1, 5 and 9 for you.
2. **`kubectl explain <kind>.<field>`**: the exact field names and nesting, without leaving the terminal.

Example: run a pod with a command. Nobody types this from memory; `k run -h` shows it:

```bash
k run probe --image=busybox --restart=Never --command -- sh -c 'wget -qO- web:80; sleep 3600'
```

Train with the docs as you will use them: for each drill, find the page **before** you start the clock, then do the drill with only that page and `-h` open. The [kubectl quick reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/) is the page to know best.

| # | Drill | Page to find | What to copy from it | Faster offline |
| --- | --- | --- | --- | --- |
| 1 | CronJob | [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) | `concurrencyPolicy`, `successfulJobsHistoryLimit`; `activeDeadlineSeconds` is in the Job spec | `k create cronjob -h` |
| 2 | Init + sidecar | [Sidecar containers](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/), [Init containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) | The sidecar example YAML: an init container with `restartPolicy: Always` | — |
| 3 | SecurityContext | [Configure a Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) | `runAsNonRoot`, `readOnlyRootFilesystem`, `capabilities: drop` | `k explain pod.spec.containers.securityContext` |
| 4 | Quota + LimitRange | [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/), [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/) | `limits.cpu`, `defaultRequest`, `default` | `k create quota -h` |
| 5 | Ingress | [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) | The minimal Ingress example; `pathType: Prefix` | `k create ingress -h` (the examples cover both rules) |
| 6 | Kustomize | [Managing objects with Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) | `replicas`, `labels`, `images` fields of `kustomization.yaml` | `k kustomize <dir>` to preview |
| 7 | Helm | [helm.sh/docs](https://helm.sh/docs/helm/helm_upgrade/): `helm upgrade` | `--set`, `--reuse-values`, `-f values.yaml` | `helm upgrade -h`, `helm show values` |
| 8 | Canary | [Managing workloads → Canary deployments](https://kubernetes.io/docs/concepts/workloads/management/#canary-deployments) | Two Deployments, one Service selecting a shared label | `k scale -h` |
| 9 | RBAC | [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/), [Configure Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) | `automountServiceAccountToken: false` | `k create role -h`, `k create rolebinding -h`, `k auth can-i --as` |
| 10 | Fix a broken app | [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/), [Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/) | `readinessProbe.httpGet` | `k describe`, `k get events --sort-by=.lastTimestamp`, `k logs --previous` |
| 11 | CRD | [Extend the API with CustomResourceDefinitions](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/) | The full CRD example: `versions`, `served`, `storage`, `schema.openAPIV3Schema` | `k explain crd.spec` |
| 12 | Build an image | [Images → imagePullPolicy](https://kubernetes.io/docs/concepts/containers/images/), [Configure a Pod to use a ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) | `valueFrom.configMapKeyRef` | `k create configmap -h`, `k set env -h` |

The drills and levels 1–4 are plain Kubernetes. Levels 5–9 teach how a production platform runs (Karpenter, Argo CD, External Secrets, Gateway API): useful at work, **not on the exam**.

## Exam setup to practise with

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"   # k create deploy web --image=nginx $do > web.yaml
export now="--force --grace-period=0"  # k delete pod web $now
source <(kubectl completion bash); complete -o default -F __start_kubectl k
```

In `~/.vimrc`: `set expandtab tabstop=2 shiftwidth=2`.

- Switch context and namespace at the start of **every** task: the exam uses several clusters.
- `kubectl explain <kind>.spec --recursive | less` replaces most doc lookups.
- Flag a hard task and move on. Points are per task; a stuck task costs the ones after it.

## Before the exam

- Two **killer.sh** sessions come with the exam, each open for 36 hours. Do the first about two weeks before, under exam conditions. Do the second 2–5 days before. killer.sh is harder than the real exam on purpose.
- Re-run every drill you finished over its target time until it is under.
