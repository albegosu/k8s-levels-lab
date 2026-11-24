# Level 7 · Storage and the cloud around the cluster

[Español](README.es.md)

## Concepts

- **PersistentVolumeClaim** asks for disk ("1Gi, ReadWriteOnce"); a **StorageClass** says how to create it. On EKS that is usually `gp3` (EBS); on kind it is `standard` (local-path).
- A block volume lives in **one zone** (on kind, on one node). The pod using it can only run there: if no node can be created in that zone, it stays Pending.
- `reclaimPolicy: Delete` deletes the disk when the PVC is deleted.
- Everything around the cluster is usually managed with **Terraform**: VPC and subnets, the EKS cluster and its private endpoint, a fixed system node group, IAM roles for IRSA, secret managers, DNS zones. Changes go through a merge request where **Atlantis** comments the `plan` and applies it.
- **Velero** backs up Kubernetes objects to object storage and snapshots volumes.

## Volumes

```bash
kubectl get storageclass
kubectl apply -f level-7/pvc.yaml
kubectl get pvc,pv -n sandbox             # Pending until a pod uses it (WaitForFirstConsumer)
kubectl apply -f level-7/pod-with-disk.yaml
kubectl get pvc,pv -n sandbox
kubectl exec -n sandbox with-disk -- sh -c 'echo hello > /data/file; cat /data/file'
kubectl delete pod with-disk -n sandbox
kubectl apply -f level-7/pod-with-disk.yaml
kubectl exec -n sandbox with-disk -- cat /data/file    # the data outlives the pod
kubectl get pv -o jsonpath='{.items[*].spec.nodeAffinity}'; echo   # the volume is tied to a node
```

That last command is the local equivalent of "an EBS volume lives in one zone".

## Reading Terraform

If you have access to a platform's Terraform, read it with these questions:

- Is the cluster API endpoint public or private, and from which networks can you reach it?
- Which instance types does the system node group use, and why are they fixed rather than Karpenter-managed?
- Which ServiceAccount can assume each IRSA role?

```bash
grep -n 'module "' *.tf
terraform fmt -check -recursive   # lists badly formatted files; changes nothing
```

## Check yourself

- [ ] Why can a pod with a volume stay Pending while other nodes are free?
- [ ] Which repo do you change to give an app cloud permissions, and which to deploy it?
