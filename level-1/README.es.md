# Nivel 1 · Fundamentos

[English](README.md)

## Conceptos

- **Imagen y contenedor.** Una imagen es un paquete cerrado con una app y todo lo que necesita; un contenedor es esa imagen en ejecución. Las imágenes viven en un registro y el **tag** indica la versión.
- **Clúster.** Un **control plane** (API server, etcd, scheduler, controladores) que decide, y **nodos** que ejecutan contenedores a través del **kubelet**.
- **Estado deseado.** No dices "arranca dos contenedores", dices "quiero dos". Los controladores comparan sin parar lo que hay con lo que quieres y corrigen la diferencia.
- **Pod.** La unidad mínima que Kubernetes programa: uno o varios contenedores que comparten red y disco. Es efímero: un pod muerto se sustituye por otro con otro nombre e IP, nunca se resucita. Corre en un nodo y no se mueve.
- **Namespace.** Una carpeta lógica que separa nombres, permisos y cuotas.
- **Manifiesto.** YAML con `apiVersion`, `kind`, `metadata` y `spec` (lo que quieres); Kubernetes añade `status` (lo que hay). Comparar `spec` y `status` es el primer paso de cualquier investigación.

## Ejercicios

```bash
kubectl config current-context          # tiene que decir kind-lab
kubectl get nodes -o wide -L role,karpenter.sh/nodepool
kubectl create namespace sandbox
kubectl apply -f level-1/pod.yaml
kubectl get pods -n sandbox -w           # Ctrl+C cuando esté Running
kubectl describe pod hello -n sandbox    # lee los Events del final
kubectl get pod hello -n sandbox -o yaml # compara spec con status
kubectl logs hello -n sandbox
kubectl delete pod hello -n sandbox
kubectl get pods -n sandbox              # no vuelve: nadie lo vigila
kubectl apply -f level-1/pod-broken.yaml
kubectl describe pod broken -n sandbox   # ImagePullBackOff y su causa
kubectl delete -f level-1/pod-broken.yaml
kubectl explain pod.spec.containers.image
```

| Comando | Para qué |
| --- | --- |
| `kubectl get` | Listar objetos y su estado |
| `kubectl describe` | Detalle y eventos recientes: lo primero cuando algo falla |
| `kubectl logs` | Salida del contenedor; `--previous` para el que murió |
| `kubectl get events --sort-by=.lastTimestamp` | Qué ha pasado en un namespace |
| `kubectl get -o yaml` | El objeto completo, `spec` y `status` |

## Comprueba que lo has entendido

- [ ] ¿Por qué no vuelve un pod borrado a mano?
- [ ] ¿En qué nodo cayó `hello` y por qué no en `lab-control-plane`? Pista: `kubectl describe node lab-control-plane | grep Taints`.
- [ ] ¿Dónde lees por qué un pod no arranca?
