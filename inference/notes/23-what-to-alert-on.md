# What to alert on

**In one line:** page on what users feel (latency against the SLO, errors, a backend down), open a ticket for saturation that will hurt soon, and send hardware faults to whoever replaces nodes; never page on GPU utilisation.

## Three kinds of alert

| Kind | Fires when | Who gets it | Example |
| --- | --- | --- | --- |
| **Symptom** (page) | Users are affected now | On-call | TTFT p95 over target for 10 min |
| **Saturation** (ticket) | Capacity is running out, users still fine | Platform team, working hours | Requests queued for 15 min |
| **Hardware** (page or ticket) | A GPU or node is broken | Platform team | Fatal XID error |

The rule: an alert that pages must mean "a user is having a bad time and a human must act". Everything else is a ticket or a dashboard.

## Start with SLOs

Alerts are only as good as the targets behind them. Write them down per model, per kind of traffic:

| Traffic | TTFT p95 | ITL p95 | Errors |
| --- | --- | --- | --- |
| Chat | < 1 s | < 50 ms | < 1 % |
| Coding agent | < 3 s (long prompts) | < 50 ms | < 1 % |
| Batch / offline | not alerted | not alerted | < 5 %, ticket |

These are starting points; agree yours with whoever owns the product.

## The alert set

The file [`inference/manifests/prometheusrule-inference.yaml`](../manifests/prometheusrule-inference.yaml) implements this table as a `PrometheusRule` for kube-prometheus-stack (level 8).

| Alert | Expression, in words | For | Kind | First thing to check |
| --- | --- | --- | --- | --- |
| `InferenceTTFTHigh` | TTFT p95 > 3 s | 10m | page | Waiting requests and KV usage: capacity or long prompts? |
| `InferenceITLHigh` | ITL p95 > 50 ms | 10m | page | Running requests: batch too big (speed ceiling) |
| `InferenceGatewayErrors` | failed ÷ total at the gateway > 5 % | 5m | page | 429 or 422 (limits, budgets) or 5xx (backend)? |
| `InferenceBackendDown` | `litellm_deployment_state` = 2 | 2m | page | Model server pods: restarts, OOMKilled, Pending |
| `InferenceRequestsQueued` | waiting > 0 | 15m | ticket | Memory ceiling: scale out or shrink KV |
| `InferenceKVCacheFull` | KV usage > 90 % on average | 30m | ticket | Capacity trend; plan the next replica |
| `InferencePreempting` | preemptions > 0.1/s | 15m | ticket | Cache too small for the contexts in use |
| `InferenceBudgetAlmostSpent` | team budget < 10 | 1h | ticket | Tell the team before they get errors (LiteLLM answers 422 `budget_exceeded`) |
| `GPUXidError` | XID 48, 79, 94 or 95 | — | page | Cordon, drain and replace the node |
| `GPURowRemapFailed` | row remap failed | — | ticket | Replace the node |
| `GPUHot` | > 85 °C | 10m | ticket | Throttling: speeds drop without errors |
| `GPUPodPending` | Pod asking for `nvidia.com/gpu` Pending | 15m | ticket | Quota, capacity, NodePool limits, taints |

## What not to alert on

| Signal | Why not |
| --- | --- |
| GPU utilisation high | It is 100 % whenever any kernel runs (note 22). A busy GPU is the goal |
| GPU memory near full | vLLM reserves 90 % at start-up on purpose (`--gpu-memory-utilization`) |
| Single slow requests | One 100k-token prompt is slow by nature. Use percentiles over minutes |
| Average latency | Hides the tail (note 15) |
| Spend per hour | Budgets in the gateway already block; alert on remaining budget instead |

## XID errors in one paragraph

The NVIDIA driver reports GPU faults as numbered **XID** events (in the kernel log, and in DCGM). Some come from the application (13, 31, 43: a bad kernel or memory access) and go away with a pod restart. Others mean the hardware is unreliable: **48** (double-bit ECC error), **79** (the GPU fell off the bus), **94/95** (contained / uncontained ECC error). For those, restarting the pod puts it back on the same broken GPU. Cordon and drain the node and let the autoscaler bring a new one.

## Try it

1. Read the `PrometheusRule` file. For each page alert, write the first `kubectl` or PromQL command you would run.
2. With the level 8 stack up: `kubectl apply -f inference/manifests/prometheusrule-inference.yaml`, then open Prometheus → Alerts. The rules load (with no data on kind) and you can check the expressions parse.

## Check yourself

<details><summary>1. KV cache is at 95 % all afternoon, TTFT is within target. Page or not?</summary>
No. It is saturation without user impact: a ticket to plan capacity. vLLM is designed to run with a full cache.
</details>
<details><summary>2. The gateway error rate is 8 %, all of them 429 or 422. Who acts?</summary>
Probably nobody on-call: limits or budgets doing their job. Split the alert by error class (page only on 5xx) and tell the tenant: 429 is a rate limit, 422 an exhausted budget.
</details>
<details><summary>3. A node reports XID 79. Why is restarting the pod not enough?</summary>
The GPU is gone from the bus; the pod would be rescheduled onto the same broken hardware. Drain and replace the node.
</details>

## Read more (15 min)

- [Google SRE book: Monitoring distributed systems](https://sre.google/sre-book/monitoring-distributed-systems/): "Symptoms Versus Causes" and "The Four Golden Signals".
- [NVIDIA Xid errors](https://docs.nvidia.com/deploy/xid-errors/index.html): "Analyzing Xid Errors with the Xid Catalog", the meaning and recommended action for each XID.
