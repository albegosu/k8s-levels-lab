# Level 4 · Config, secrets and identity

[Español](README.es.md)

The `external-secrets` add-on is installed by `./lab.sh up`.

## Concepts

- **ConfigMap.** Non-secret key/value config, injected as env vars or files.
- **Secret.** Same, for sensitive data. By default it is only base64, not encrypted: never commit one to Git.
- **External Secrets Operator.** The real value lives in a secret manager (AWS Secrets Manager, Vault, 1Password…). A **SecretStore** says where and how to read; an **ExternalSecret** says what to read and which Secret to create. Changing the source value does not restart pods: env vars are read at start-up.
- **ServiceAccount.** The pod's identity, towards the Kubernetes API and, on EKS, towards AWS.
- **RBAC.** Role / ClusterRole (permissions) and RoleBinding / ClusterRoleBinding (who gets them). Everything not granted is denied.
- **IRSA** (EKS): a ServiceAccount annotated with an IAM role gets temporary AWS credentials through the cluster's OIDC provider. It cannot run on kind; look at the annotation in `worker.yaml`.

## A Secret is not encrypted

```bash
kubectl create secret generic token --from-literal=TOKEN=s3cr3t -n sandbox
kubectl get secret token -n sandbox -o jsonpath='{.data.TOKEN}' | base64 -d; echo
```

## From the secret manager to the pod

```bash
kubectl apply -f level-4/worker.yaml
kubectl get pods -n shop -l app.kubernetes.io/component=worker   # CreateContainerConfigError: shop-app is missing
kubectl describe pod -n shop -l app.kubernetes.io/component=worker | tail -5
kubectl apply -f level-4/secret-store.yaml -f level-4/external-secret.yaml
kubectl get secretstore,externalsecret -n shop     # SecretSynced
kubectl get pods -n shop -l app.kubernetes.io/component=worker -w
kubectl logs deploy/shop-worker -n shop
```

Change `DATABASE_URL` in `level-4/secret-store.yaml`, apply it again and wait a minute. The Secret changes, the log does not: you need a restart.

```bash
kubectl rollout restart deployment/shop-worker -n shop
kubectl logs deploy/shop-worker -n shop
```

External Secrets prints a warning that the fake provider is not maintained: it is meant for tests like this one.

## RBAC

```bash
kubectl apply -f level-4/rbac.yaml
kubectl auth can-i list pods -n shop --as=system:serviceaccount:shop:reader      # yes
kubectl auth can-i get secrets -n shop --as=system:serviceaccount:shop:reader    # no
kubectl auth can-i list pods -n sandbox --as=system:serviceaccount:shop:reader   # no: the Role lives in shop
kubectl auth can-i --list -n shop --as=system:serviceaccount:shop:reader
```

## Check your work

```bash
./lab.sh check 4
```

It checks the path from the secret store to the pod, and that `reader` cannot read Secrets.

## Check yourself

- [ ] Where do you change a secret, and what must happen for the app to pick it up?
- [ ] Explain IRSA in four steps.
- [ ] Tell permissions inside the cluster (RBAC) from permissions in the cloud (IAM).
