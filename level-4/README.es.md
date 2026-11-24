# Nivel 4 · Configuración, secretos e identidad

[English](README.md)

El addon `external-secrets` lo instala `./lab.sh up`.

## Conceptos

- **ConfigMap.** Configuración no secreta en pares clave-valor, que llega al pod como variables de entorno o ficheros.
- **Secret.** Lo mismo, para datos sensibles. Por defecto solo está en base64, no cifrado: nunca lo subas a Git.
- **External Secrets Operator.** El valor real vive en un gestor de secretos (AWS Secrets Manager, Vault, 1Password…). Un **SecretStore** dice dónde y cómo leer; un **ExternalSecret** dice qué leer y qué Secret crear. Cambiar el valor de origen no reinicia los pods: las variables de entorno se leen al arrancar.
- **ServiceAccount.** La identidad del pod ante el API de Kubernetes y, en EKS, ante AWS.
- **RBAC.** Role / ClusterRole (permisos) y RoleBinding / ClusterRoleBinding (quién los recibe). Todo lo que no se da está denegado.
- **IRSA** (EKS): una ServiceAccount anotada con un rol IAM obtiene credenciales temporales de AWS a través del proveedor OIDC del clúster. No funciona en kind; mira la anotación de `worker.yaml`.

## Un Secret no está cifrado

```bash
kubectl create secret generic token --from-literal=TOKEN=s3cr3t -n sandbox
kubectl get secret token -n sandbox -o jsonpath='{.data.TOKEN}' | base64 -d; echo
```

## Del gestor de secretos al pod

```bash
kubectl apply -f level-4/worker.yaml
kubectl get pods -n shop -l app.kubernetes.io/component=worker   # CreateContainerConfigError: falta shop-app
kubectl describe pod -n shop -l app.kubernetes.io/component=worker | tail -5
kubectl apply -f level-4/secret-store.yaml -f level-4/external-secret.yaml
kubectl get secretstore,externalsecret -n shop     # SecretSynced
kubectl get pods -n shop -l app.kubernetes.io/component=worker -w
kubectl logs deploy/shop-worker -n shop
```

Cambia `DATABASE_URL` en `level-4/secret-store.yaml`, vuelve a aplicarlo y espera un minuto. El Secret cambia, pero el log no: hay que reiniciar.

```bash
kubectl rollout restart deployment/shop-worker -n shop
kubectl logs deploy/shop-worker -n shop
```

External Secrets avisa de que el provider fake no se mantiene: está pensado para pruebas como esta.

## RBAC

```bash
kubectl apply -f level-4/rbac.yaml
kubectl auth can-i list pods -n shop --as=system:serviceaccount:shop:reader      # yes
kubectl auth can-i get secrets -n shop --as=system:serviceaccount:shop:reader    # no
kubectl auth can-i list pods -n sandbox --as=system:serviceaccount:shop:reader   # no: el Role es de shop
kubectl auth can-i --list -n shop --as=system:serviceaccount:shop:reader
```

## Corrige tu trabajo

```bash
LAB_LANG=es ./lab.sh check 4
```

Comprueba el camino del gestor de secretos al pod y que `reader` no puede leer Secrets.

## Comprueba que lo has entendido

- [ ] ¿Dónde se cambia un secreto y qué tiene que pasar para que la app lo coja?
- [ ] Explica IRSA en cuatro pasos.
- [ ] Distingue los permisos dentro del clúster (RBAC) de los permisos en la nube (IAM).
