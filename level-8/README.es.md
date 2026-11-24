# Nivel 8 · Observabilidad

[English](README.md)

Consume unos 1,5 GB más de memoria.

## Conceptos

- Tres señales: **métricas** (números en el tiempo), **logs** (lo que escriben las apps) y **trazas** (el camino de una petición entre servicios).
- **Prometheus** pide las métricas (scrape). Qué pedir se declara con un **ServiceMonitor**; las reglas de alerta van en una **PrometheusRule**. **Alertmanager** agrupa y envía alertas (Slack, Discord, PagerDuty…). **Grafana** consulta todo.
- **kube-prometheus-stack** los trae juntos, más `node-exporter` (un DaemonSet con métricas de cada nodo) y `kube-state-metrics` (estado de los objetos: réplicas deseadas, pods Pending, reinicios).
- Los logs suele recogerlos un agente en DaemonSet (Grafana Alloy, Fluent Bit) y guardarse en Loki; las trazas van a Tempo. No se instalan aquí para ahorrar memoria.

## Instalar y abrir

```bash
./lab.sh addon monitoring
kubectl get pods -n observability -o wide
kubectl get daemonset -n observability          # node-exporter: uno por nodo
kubectl port-forward svc/kps-grafana -n observability 3000:80
```

Grafana en `http://localhost:3000`, usuario `admin`, contraseña `lab`.

## Métricas de una app

Necesita `level-2/web.yaml` y `level-3/service.yaml` aplicados.

```bash
kubectl apply -f level-8/servicemonitor.yaml
kubectl port-forward svc/kps-kube-prometheus-stack-prometheus -n observability 9090:9090
```

Al cabo de uno o dos minutos aparece `shop/shop-web` en `http://localhost:9090/targets`. Prueba en Grafana → Explore → Prometheus:

```
http_requests_total{namespace="shop"}
kube_pod_status_phase{phase="Pending"} == 1
sum by (node) (kube_pod_container_resource_requests{resource="memory"}) / 1024 / 1024
```

La última es la cifra que mira el scheduler: requests por nodo.

## Una alerta

```bash
kubectl apply -f level-8/prometheusrule.yaml
./level-5/reproduce-incident.sh                  # deja un pod Pending
kubectl port-forward svc/kps-kube-prometheus-stack-alertmanager -n observability 9093:9093
```

En `http://localhost:9090/alerts` la alerta pasa de `Pending` a `Firing` a los 2 minutos, y aparece en `http://localhost:9093`.

## Comprueba que lo has entendido

- [ ] ¿Dónde buscas los logs de un pod que ya no existe?
- [ ] ¿Por qué un agente de logs es un DaemonSet y Prometheus no?
- [ ] ¿Qué objeto creas para que Prometheus recoja métricas de una app nueva?
