# Nivel 7 · Almacenamiento y la nube alrededor del clúster

[English](README.md)

## Conceptos

- Un **PersistentVolumeClaim** pide disco ("1Gi, ReadWriteOnce"); una **StorageClass** dice cómo crearlo. En EKS suele ser `gp3` (EBS); en kind es `standard` (local-path).
- Un volumen de bloque vive en **una zona** (en kind, en un nodo). El pod que lo usa solo puede correr ahí: si no se puede crear un nodo en esa zona, se queda Pending.
- `reclaimPolicy: Delete` borra el disco al borrar el PVC.
- Todo lo que rodea al clúster se suele gestionar con **Terraform**: VPC y subredes, el clúster EKS y su endpoint privado, un node group fijo de sistema, roles IAM para IRSA, gestores de secretos y zonas DNS. Los cambios van por merge request, donde **Atlantis** comenta el `plan` y lo aplica.
- **Velero** guarda copias de los objetos de Kubernetes en almacenamiento de objetos y snapshots de los volúmenes.

## Volúmenes

```bash
kubectl get storageclass
kubectl apply -f level-7/pvc.yaml
kubectl get pvc,pv -n sandbox             # Pending hasta que un pod lo usa (WaitForFirstConsumer)
kubectl apply -f level-7/pod-with-disk.yaml
kubectl get pvc,pv -n sandbox
kubectl exec -n sandbox with-disk -- sh -c 'echo hello > /data/file; cat /data/file'
kubectl delete pod with-disk -n sandbox
kubectl apply -f level-7/pod-with-disk.yaml
kubectl exec -n sandbox with-disk -- cat /data/file    # el dato sobrevive al pod
kubectl get pv -o jsonpath='{.items[*].spec.nodeAffinity}'; echo   # el volumen está atado a un nodo
```

Ese último comando es el equivalente local de "un volumen EBS vive en una zona".

## Leer Terraform

Si tienes acceso al Terraform de una plataforma, léelo con estas preguntas:

- ¿El endpoint del API del clúster es público o privado, y desde qué redes se llega?
- ¿Qué tipos de instancia usa el node group de sistema y por qué es fijo y no lo gestiona Karpenter?
- ¿Qué ServiceAccount puede asumir cada rol IRSA?

```bash
grep -n 'module "' *.tf
terraform fmt -check -recursive   # lista los ficheros mal formateados; no cambia nada
```

## Corrige tu trabajo

```bash
LAB_LANG=es ./lab.sh check 7
```

Comprueba que el fichero sobrevivió al pod y que el volumen está atado a un nodo.

## Comprueba que lo has entendido

- [ ] ¿Por qué un pod con volumen puede quedarse Pending aunque haya otros nodos libres?
- [ ] ¿Qué repo cambias para dar permisos de nube a una app y cuál para desplegarla?
