# Pista CKAD

[English](README.md)

Doce ejercicios contra reloj para el examen **Certified Kubernetes Application Developer** (temario de Kubernetes v1.37). Cubren lo que pide el CKAD y no cubren los niveles 1–9. Cada ejercicio va en su propio namespace y se corrige como un nivel.

```bash
./lab.sh drill 1          # crea ckad-1, carga los manifiestos de partida y arranca el reloj
./lab.sh drill 1 check    # lo corrige y te dice cuánto has tardado
```

El examen da 2 horas para unas 15–20 tareas: entre 6 y 8 minutos cada una. Apunta a los tiempos objetivo de la tabla, con comandos imperativos primero y YAML solo donde no llegan.

## Dominios del examen y dónde practicarlos

| Dominio | Peso | Niveles del lab | Ejercicios |
| --- | --- | --- | --- |
| Application Design and Build | 20 % | 2 (workloads), 7 (volúmenes) | 1 CronJob, 2 init + sidecar, 12 construir una imagen |
| Application Deployment | 20 % | 2 (rolling updates), 6 (Helm) | 6 Kustomize, 7 Helm, 8 canary |
| Application Observability and Maintenance | 15 % | 8 (probes, métricas), 9 (diagnóstico) | 10 arreglar una app rota |
| Application Environment, Configuration and Security | 25 % | 4 (ConfigMap, Secret, RBAC), 5 (requests, limits) | 3 SecurityContext, 4 quotas, 9 RBAC, 11 CRD |
| Services and Networking | 20 % | 3 (Service, NetworkPolicy) | 5 Ingress |

**Ingress, no Gateway API.** El nivel 3 usa Gateway API, que es hacia donde van las plataformas. El CKAD sigue pidiendo objetos `Ingress`, así que el ejercicio 5 consiste en escribirlos. En el lab no hay controlador de Ingress: el ejercicio corrige el objeto, no el tráfico.

## Ejercicios

Los enunciados completos y los tiempos objetivo están en la tabla de [README.md](README.md#drills); los checks avisan en español de qué falta en cada tarea.

## Búscalo en la documentación, no lo memorices

El examen es a libro abierto, con límites: en el navegador del examen puedes usar **[kubernetes.io/docs](https://kubernetes.io/docs/)**, el **[blog de Kubernetes](https://kubernetes.io/blog/)** y **[helm.sh/docs](https://helm.sh/docs/)** ([Linux Foundation: recursos permitidos](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed)). Nadie recuerda todos los campos de un CronJob o de una NetworkPolicy. Lo que aprueba el examen es saber **qué página tiene el ejemplo que copiar**, y las dos fuentes sin conexión que son más rápidas que cualquier página:

1. **`kubectl <verbo> <tipo> -h`**: los ejemplos del principio de la ayuda están listos para adaptar. `k create ingress -h`, `k create cronjob -h` y `k create role -h` te escriben casi todo de los ejercicios 1, 5 y 9.
2. **`kubectl explain <tipo>.<campo>`**: los nombres exactos de los campos y cómo se anidan, sin salir del terminal.

Ejemplo: lanzar un pod con un comando. Nadie lo escribe de memoria; `k run -h` lo enseña:

```bash
k run probe --image=busybox --restart=Never --command -- sh -c 'wget -qO- web:80; sleep 3600'
```

Entrena con la documentación como la vas a usar: en cada ejercicio, encuentra la página **antes** de arrancar el reloj y haz el ejercicio solo con esa página y `-h` abiertos. La [kubectl quick reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/) es la página que más tienes que conocer.

| # | Ejercicio | Página que encontrar | Qué copiar de ella | Más rápido sin conexión |
| --- | --- | --- | --- | --- |
| 1 | CronJob | [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) | `concurrencyPolicy`, `successfulJobsHistoryLimit`; `activeDeadlineSeconds` va en el spec del Job | `k create cronjob -h` |
| 2 | Init + sidecar | [Sidecar containers](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/), [Init containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) | El YAML de ejemplo del sidecar: un init container con `restartPolicy: Always` | — |
| 3 | SecurityContext | [Configure a Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) | `runAsNonRoot`, `readOnlyRootFilesystem`, `capabilities: drop` | `k explain pod.spec.containers.securityContext` |
| 4 | Quota + LimitRange | [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/), [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/) | `limits.cpu`, `defaultRequest`, `default` | `k create quota -h` |
| 5 | Ingress | [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) | El Ingress mínimo de ejemplo; `pathType: Prefix` | `k create ingress -h` (the examples cover both rules) |
| 6 | Kustomize | [Managing objects with Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) | Los campos `replicas`, `labels` e `images` de `kustomization.yaml` | `k kustomize <dir>` to preview |
| 7 | Helm | [helm.sh/docs](https://helm.sh/docs/helm/helm_upgrade/): `helm upgrade` | `--set`, `--reuse-values`, `-f values.yaml` | `helm upgrade -h`, `helm show values` |
| 8 | Canary | [Managing workloads → Canary deployments](https://kubernetes.io/docs/concepts/workloads/management/#canary-deployments) | Dos Deployments y un Service que selecciona una etiqueta común | `k scale -h` |
| 9 | RBAC | [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/), [Configure Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) | `automountServiceAccountToken: false` | `k create role -h`, `k create rolebinding -h`, `k auth can-i --as` |
| 10 | Arreglar una app rota | [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/), [Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/) | `readinessProbe.httpGet` | `k describe`, `k get events --sort-by=.lastTimestamp`, `k logs --previous` |
| 11 | CRD | [Extend the API with CustomResourceDefinitions](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/) | El ejemplo completo de CRD: `versions`, `served`, `storage`, `schema.openAPIV3Schema` | `k explain crd.spec` |
| 12 | Construir una imagen | [Images → imagePullPolicy](https://kubernetes.io/docs/concepts/containers/images/), [Configure a Pod to use a ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) | `valueFrom.configMapKeyRef` | `k create configmap -h`, `k set env -h` |

Los ejercicios y los niveles 1–4 son Kubernetes a secas. Los niveles 5–9 enseñan cómo funciona una plataforma en producción (Karpenter, Argo CD, External Secrets, Gateway API): útil en el trabajo, **no entra en el examen**.

## Configuración para practicar como en el examen

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"   # k create deploy web --image=nginx $do > web.yaml
export now="--force --grace-period=0"  # k delete pod web $now
source <(kubectl completion bash); complete -o default -F __start_kubectl k
```

En `~/.vimrc`: `set expandtab tabstop=2 shiftwidth=2`.

- Cambia de contexto y de namespace al empezar **cada** tarea: el examen usa varios clusters.
- `kubectl explain <kind>.spec --recursive | less` sustituye a casi todas las búsquedas en la documentación.
- Marca la tarea difícil y sigue. Los puntos van por tarea; una tarea atascada te quita las siguientes.

## Antes del examen

- El examen incluye dos sesiones de **killer.sh**, abiertas 36 horas cada una. La primera, unas dos semanas antes y en condiciones de examen. La segunda, entre 2 y 5 días antes. killer.sh es más difícil que el examen a propósito.
- Repite cada ejercicio que hayas terminado por encima de su tiempo objetivo hasta bajar de él.
