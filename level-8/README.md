# Level 8 · Observability

[Español](README.es.md)

Uses about 1.5 GB more memory.

## Concepts

- Three signals: **metrics** (numbers over time), **logs** (what apps write) and **traces** (a request's path across services).
- **Prometheus** pulls metrics (scrape). What to scrape is declared with a **ServiceMonitor**; alert rules live in a **PrometheusRule**. **Alertmanager** groups and routes alerts (Slack, Discord, PagerDuty…). **Grafana** queries everything.
- **kube-prometheus-stack** bundles them plus `node-exporter` (a DaemonSet with per-node metrics) and `kube-state-metrics` (object state: desired replicas, Pending pods, restarts).
- Logs are usually collected by a DaemonSet agent (Grafana Alloy, Fluent Bit) and stored in Loki; traces go to Tempo. They are not installed here to save memory.

## Install and open

```bash
./lab.sh addon monitoring
kubectl get pods -n observability -o wide
kubectl get daemonset -n observability          # node-exporter: one per node
kubectl port-forward svc/kps-grafana -n observability 3000:80
```

Grafana at `http://localhost:3000`, user `admin`, password `lab`.

## Metrics from an app

Needs `level-2/web.yaml` and `level-3/service.yaml` applied.

```bash
kubectl apply -f level-8/servicemonitor.yaml
kubectl port-forward svc/kps-kube-prometheus-stack-prometheus -n observability 9090:9090
```

After a minute or two, `shop/shop-web` shows up at `http://localhost:9090/targets`. Try in Grafana → Explore → Prometheus:

```
http_requests_total{namespace="shop"}
kube_pod_status_phase{phase="Pending"} == 1
sum by (node) (kube_pod_container_resource_requests{resource="memory"}) / 1024 / 1024
```

The last one is the number the scheduler looks at: requests per node.

## An alert

```bash
kubectl apply -f level-8/prometheusrule.yaml
./level-5/reproduce-incident.sh                  # leaves a Pending pod
kubectl port-forward svc/kps-kube-prometheus-stack-alertmanager -n observability 9093:9093
```

At `http://localhost:9090/alerts` the alert goes from `Pending` to `Firing` after 2 minutes, and appears at `http://localhost:9093`.

## Check your work

```bash
./lab.sh check 8
```

It checks that Prometheus scrapes `shop-web` and has loaded the alert rule.

## Check yourself

- [ ] Where do you look for the logs of a pod that no longer exists?
- [ ] Why is a log agent a DaemonSet and Prometheus is not?
- [ ] Which object do you create so Prometheus scrapes a new app?
