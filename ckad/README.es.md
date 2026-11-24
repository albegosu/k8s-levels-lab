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
