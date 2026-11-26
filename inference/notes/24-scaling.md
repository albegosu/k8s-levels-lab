# Scaling and capacity on Kubernetes

**In one line:** scale model servers on queued requests, not on CPU or GPU utilisation, and plan for cold starts of 5–15 minutes, so keep headroom instead of reacting late.

## The signal

| Candidate | Use it? | Why |
| --- | --- | --- |
| CPU usage | No | The work is on the GPU |
| GPU utilisation | No | 100 % with one request (note 22) |
| `vllm:num_requests_waiting` | **Yes** | Users are queuing: the memory ceiling is reached |
| `vllm:kv_cache_usage_perc` | As an early warning | Rises before the queue does |
| TTFT / ITL p95 | As a check | Lags, and is noisy at low traffic |

A KEDA `ScaledObject` with the Prometheus scaler does this without writing a custom metrics adapter:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: qwen3-235b
spec:
  scaleTargetRef: { name: qwen3-235b }      # the vLLM Deployment
  minReplicaCount: 2                        # never one: a replica is a failure domain
  maxReplicaCount: 6                        # bounded by GPU quota and budget
  cooldownPeriod: 1800                      # GPUs are slow to come back: scale in slowly
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://kube-prometheus-stack-prometheus.observability:9090
        query: sum(vllm:num_requests_waiting{model_name="Qwen/Qwen3-235B-A22B-FP8"})
        threshold: "5"
```

## Cold start: why reacting is too late

What happens between "scale to 3" and "replica 3 serves traffic", for a large model:

| Step | Typical time | How to shorten it |
| --- | --- | --- |
| A GPU node is created (Karpenter, level 5) | 2–5 min, or never if there is no capacity or quota | Keep a warm node; reserved capacity (Capacity Blocks, ODCR) |
| vLLM image pulled (~10 GB) | 1–3 min | Pre-pull on the node AMI, or a local registry mirror |
| Weights downloaded (70–700 GB) | 1–10 min | Weights on fast storage near the node (S3 in-region with a streaming loader such as `--load-format runai_streamer`, or a node-local cache); never from Hugging Face at start-up |
| Weights loaded to GPU, CUDA graphs captured | 1–3 min | Fewer CUDA graph sizes; smaller TP |
| Readiness probe passes | — | Probe `/health`, and give a generous `startupProbe` |

So: **keep headroom** (scale out at 60–70 % of measured capacity, note 21), **schedule** known peaks (working hours) with a cron trigger, and use `minReplicaCount` ≥ 2.

## Routing between replicas

With more than one replica, round-robin load balancing wastes prefix caching (note 14): the same agent's next call lands on a replica that does not have its prefix. And it ignores how full each replica is. Two options:

- **Session affinity** at the gateway (by key or user): simple, uneven.
- **Inference-aware routing**: the Gateway API Inference Extension (`InferencePool`), used by [llm-d](https://llm-d.ai/), picks the replica by queue depth, KV usage and prefix-cache hits. This is the direction the ecosystem is going.

## GPU nodes on Kubernetes, in short

- The **NVIDIA GPU Operator** installs the driver, the device plugin (which advertises `nvidia.com/gpu`) and the DCGM exporter.
- GPU nodes carry a **taint** (`nvidia.com/gpu:NoSchedule`) so only pods that tolerate it land there; otherwise a stray pod can block a whole GPU node.
- A **Karpenter NodePool** per GPU family, with `limits` on GPUs so an autoscaling mistake does not create 20 p5 nodes.
- Request whole GPUs: `resources.limits: { nvidia.com/gpu: 2 }` for TP=2. Requests and limits for GPUs are always equal.

## Try it

Using your benchmark (note 21): capacity per replica 40 requests, peak 120 in flight, cold start 10 minutes, and traffic that grows by 30 requests in 10 minutes at 9:00. How many replicas at 8:50, and what threshold would you set?

<details><summary>One answer</summary>
Peak needs 3 replicas at 100 %, 5 at 60–70 %. Start the day with 4–5 via a cron trigger at 8:30, and scale on waiting requests above a small threshold for the rest. Reacting at 9:00 would leave users queuing for 10 minutes.
</details>

## Check yourself

<details><summary>1. Why is minReplicaCount 1 a bad idea for a production model?</summary>
One node or GPU failure takes the model down for the whole cold start, 5–15 minutes or more.
</details>
<details><summary>2. Why a long cooldown before scaling in?</summary>
Bringing a replica back costs minutes and may fail for lack of capacity; keeping it a bit longer costs little in comparison.
</details>
<details><summary>3. What does inference-aware routing add over a plain Service?</summary>
It sends requests to the replica with free KV cache and the right cached prefix, instead of spreading them blindly.
</details>

## Read more (15 min)

- [KEDA Prometheus scaler](https://keda.sh/docs/latest/scalers/prometheus/): the trigger fields above.
- [Gateway API Inference Extension](https://gateway-api-inference-extension.sigs.k8s.io/): "Introduction" and the `InferencePool` concept.
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/overview.html): what it installs on each node.
