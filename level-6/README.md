# Level 6 · Helm and GitOps

[Español](README.es.md)

## Concepts

- **Helm** generates YAML from templates. A **chart** has `Chart.yaml`, `values.yaml` (the knobs: image tag, replicas, resources, host) and `templates/`. `helm template` renders the final YAML without installing anything.
- **Argo CD** watches Git and makes the cluster match it. Each **Application** has a **sync** status (`Synced` / `OutOfSync`) and a **health** status (`Healthy`, `Progressing`, `Degraded`, `Missing`).
- An **ApplicationSet** generates one Application per directory: adding an app is adding `apps/<name>/` to the repo.
- A typical deploy: CI builds and pushes the image, then commits the new tag to the GitOps repo; Argo CD syncs and the Deployment rolls out. **Rollback = revert that commit**, not `kubectl rollout undo`.
- `selfHeal: true` makes Argo CD undo manual changes at once. Without it, the app stays `OutOfSync` until the next sync.

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

## Argo CD with a local GitOps repo

`gitops.sh` creates a Git repo in `.gitops/`, serves it with `git daemon` on port 9418, and applies an ApplicationSet that points to it through `host.docker.internal`.

```bash
./lab.sh addon argocd
./level-6/gitops.sh up
kubectl get applicationset,application -n argocd
kubectl get pods -n shop-lab -w
```

Open the UI:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d; echo
kubectl port-forward svc/argocd-server -n argocd 8443:443
```

Go to `https://localhost:8443` with `admin` and that password.

## A CI-style deploy

```bash
./level-6/gitops.sh bump 6.7.1      # the same commit a CI pipeline makes
kubectl annotate application shop-lab -n argocd argocd.argoproj.io/refresh=normal --overwrite
kubectl get application shop-lab -n argocd -w     # OutOfSync → Synced
kubectl get pods -n shop-lab -o jsonpath='{.items[*].spec.containers[0].image}'; echo
```

Without the annotation, Argo CD polls Git every 3 minutes (or press Refresh in the UI).

## Watch Argo CD undo a manual change

```bash
kubectl scale deployment shop-web -n shop-lab --replicas=5
kubectl get pods -n shop-lab -w     # selfHeal brings it back to 2
```

Real rollback: `git -C .gitops/platform-gitops-lab revert --no-edit HEAD`.

## Check your work

```bash
./lab.sh check 6
```

Run it before `./level-6/gitops.sh down`. It checks that Argo CD is Synced and Healthy, the bump is live and selfHeal kept 2 replicas.

## Clean up

```bash
./level-6/gitops.sh down
```

## Check yourself

- [ ] Which commit do you revert to go back to the previous version of an app?
- [ ] Why does a `kubectl edit` on a GitOps cluster not last?
- [ ] What happens if you create `apps/new` in the GitOps repo?
- [ ] Tell `OutOfSync` from `Degraded`.
