# Nivel 9 · Operación

[English](README.md)

## Un método de diagnóstico

Ve de fuera hacia dentro y lee los eventos antes de tocar nada:

1. **¿Clúster correcto?** `kubectl config current-context`.
2. **¿Qué dice GitOps?** `OutOfSync` = Git y clúster difieren; `Degraded` = algo no arranca.
3. **¿Estado de los pods?** `kubectl get pods -n <ns> -o wide`.
4. **¿Eventos?** `kubectl describe pod` y `kubectl get events --sort-by=.lastTimestamp`. Casi siempre la respuesta está aquí.
5. **Pending:** lee el `FailedScheduling`; mira los requests de los nodos y si se está creando un nodo.
6. **CrashLoopBackOff:** `kubectl logs --previous`; mira si falta un Secret.
7. **Running pero no responde:** endpoints del Service, estado de la HTTPRoute, DNS.

| Síntoma | Primer sospechoso |
| --- | --- |
| `Pending` | Sin hueco de requests, afinidad o selector, zona del volumen |
| `ImagePullBackOff` | Tag equivocado, permisos del registro, arquitectura |
| `CrashLoopBackOff` | La app falla al arrancar, falta configuración |
| `CreateContainerConfigError` | Falta un Secret o un ConfigMap |
| `OOMKilled` | Limit de memoria demasiado bajo |
| 503 desde fuera | Sin pods listos, selector del Service equivocado |

## Cinco averías

```bash
kubectl apply -f level-9/faults.yaml
kubectl get pods -n faults
```

Hay cinco averías: `api`, `worker`, `web`, `reports` y `queue`. Para cada una, sin abrir el YAML:

1. Di el síntoma (estado del pod o del Service).
2. Encuentra la causa con `describe`, `logs`, `events` o `get endpointslices`.
3. Di de qué nivel es el concepto y cómo lo arreglarías.

```bash
kubectl get events -n faults --sort-by=.lastTimestamp
kubectl describe pod -n faults -l app=<nombre>
kubectl logs -n faults deploy/<nombre> --previous
kubectl get svc,endpointslices -n faults
```

## Corrige tu trabajo

```bash
LAB_LANG=es ./lab.sh check 9
```

Misión: arregla las cinco averías en su sitio (edita, parchea o crea lo que falta) sin borrar los Deployments. El check pasa cuando las cinco corren.

Después compara con [solutions.es.md](solutions.es.md).

```bash
kubectl delete namespace faults
```
