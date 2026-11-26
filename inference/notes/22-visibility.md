# Visibility: what to look at

**In one line:** watch four layers, gateway, engine, GPU and Kubernetes, and read them top-down: users feel the gateway, the engine explains why, the GPU and the cluster explain what broke underneath.

## The four layers

| Layer | Exporter | Answers | Key metrics |
| --- | --- | --- | --- |
| **Gateway** (LiteLLM) | `/metrics` with `callbacks: ["prometheus"]` | Who uses it, how much it costs, which backend fails | `litellm_proxy_total_requests_metric_total`, `litellm_proxy_failed_requests_metric_total`, `litellm_request_total_latency_metric`, `litellm_spend_metric_total`, `litellm_total_tokens_metric_total`, `litellm_remaining_api_key_budget_metric`, `litellm_deployment_state` |
| **Engine** (vLLM) | `/metrics` on the serving port | Is it saturated, are users waiting, how fast are tokens | `vllm:num_requests_running`, `vllm:num_requests_waiting`, `vllm:kv_cache_usage_perc`, `vllm:num_preemptions_total`, `vllm:time_to_first_token_seconds`, `vllm:inter_token_latency_seconds`, `vllm:e2e_request_latency_seconds`, `vllm:request_queue_time_seconds`, `vllm:prompt_tokens_total`, `vllm:generation_tokens_total`, `vllm:prefix_cache_hits_total` |
| **GPU** | NVIDIA DCGM exporter (installed by the GPU Operator) | Is the hardware healthy and busy | Memory used, utilisation, tensor-core and DRAM activity, temperature, power, XID errors, row remapping |
| **Kubernetes** | kube-state-metrics (level 8) | Is the pod running where it should | Restarts, `OOMKilled`, Pending pods asking for `nvidia.com/gpu`, node conditions |

Every vLLM metric carries a `model_name` label. Counters get a `_total` suffix when scraped, in vLLM and in LiteLLM (`litellm_spend_metric` is scraped as `litellm_spend_metric_total`), and LiteLLM protects `/metrics` with a key, so Prometheus needs a bearer token (level 10 shows how). Metric names change between versions of vLLM and of the DCGM exporter (recent DCGM exporters rename `DCGM_FI_DEV_GPU_UTIL` to `DCGM_FI_DEV_GPU_UTIL_RATIO`, `DCGM_FI_DEV_FB_USED` to `DCGM_FI_DEV_FB_USED_BYTES`…): **`curl` each `/metrics` once and copy the names you see**.

## GPU utilisation lies

The classic "GPU util" (`DCGM_FI_DEV_GPU_UTIL` or `nvidia-smi`) is the fraction of time **any** kernel was running. A server decoding one request at a time shows 100 % while using a small part of the GPU. Do not size, alert or autoscale on it. Use instead:

- **for saturation:** `vllm:num_requests_waiting` and `vllm:kv_cache_usage_perc`;
- **for real GPU activity:** the profiling fields, tensor-core activity and DRAM (bandwidth) activity. In decode, DRAM activity near 1 means you are bandwidth-bound, which is expected (note 09).

## The dashboard, in reading order

| Row | Panels | PromQL |
| --- | --- | --- |
| **1. Are users OK?** | TTFT p95, ITL p95, error rate, requests waiting | `histogram_quantile(0.95, sum by (le, model_name) (rate(vllm:time_to_first_token_seconds_bucket[5m])))` |
| **2. How full is it?** | KV cache usage, running requests, preemptions/s, queue time p95 | `max by (model_name) (vllm:kv_cache_usage_perc)` · `sum by (model_name) (rate(vllm:num_preemptions_total[5m]))` |
| **3. How much work?** | Prompt and generation tokens/s, prefix cache hit rate, requests by `finished_reason` | `sum(rate(vllm:generation_tokens_total[5m]))` · `rate(vllm:prefix_cache_hits_total[5m]) / rate(vllm:prefix_cache_queries_total[5m])` |
| **4. Who and how much?** | Requests, tokens and spend per key and team, remaining budget, backend state | `sum by (team) (rate(litellm_spend_metric_total[1h]))` |
| **5. Is the hardware healthy?** | GPU memory, temperature, power, XID, row remap | from the DCGM exporter |

Ready-made dashboards: vLLM ships Grafana examples under `examples/observability`, and NVIDIA publishes a DCGM exporter dashboard (Grafana ID 12239). Start from them, then reorder by the rows above.

## Reading it in an incident

| Symptom (row 1) | Look at (rows 2–5) | Likely cause |
| --- | --- | --- |
| TTFT up, ITL fine | Waiting requests up, KV usage near 1 | Out of capacity: memory ceiling (note 20) |
| TTFT up, KV usage low | Prompt tokens/s jumped | Very long prompts: prefill-bound (note 04) |
| ITL up, KV usage below 1 | Running requests high | Speed ceiling: batch too large for the target |
| Errors up at the gateway | `litellm_deployment_state` = 2, pod restarts | Backend down: OOMKilled, XID error, node lost |
| Spend jumps for one key | Tokens per key | One agent in a loop |

## Try it

If you have a vLLM server: `curl -s <server>/metrics | grep -E '^vllm:(num_requests|kv_cache)'`. With the kind cluster from level 8, write the ServiceMonitor you would need to scrape it (port name, path `/metrics`).

## Check yourself

<details><summary>1. GPU util is 100 % and users are happy. Is the GPU full?</summary>
Not necessarily: util only says some kernel was running. Check KV usage and waiting requests.
</details>
<details><summary>2. Which single panel tells you users are waiting for capacity?</summary>
`vllm:num_requests_waiting` above zero for minutes, usually with KV usage near 1.
</details>
<details><summary>3. Why keep the gateway and engine metrics separate?</summary>
The gateway sees users, keys and all backends (including external APIs); the engine sees one model server's internals. You need both to go from "team X is slow" to "replica 2 is out of KV cache".
</details>

## Read more (15 min)

- [vLLM production metrics](https://docs.vllm.ai/en/latest/usage/metrics.html): the full list, with types.
- [LiteLLM Prometheus metrics](https://docs.litellm.ai/docs/proxy/prometheus): "Proxy Level Tracking Metrics" and "LLM Provider Metrics".
- [NVIDIA DCGM exporter](https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/latest/dcgm-exporter.html): which fields are on by default and how to add more.
