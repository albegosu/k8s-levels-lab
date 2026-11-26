# Cases: customer tickets to solve blind

Twelve tickets of the kind inference customers send. Each gives you the customer's words and a snapshot of what you could see in the dashboards or logs. Before opening the solution, write down:

1. **Metric, layer, phase, ceiling** (note 25).
2. **The next question or check** you would make, and why.
3. **The reply to the customer**, in three parts (note 26).

Then compare. The solutions name the equations from note 18 they rely on: if you missed one, reread it.

---

## Case 1 · "Every morning it crawls"

> "Between 9 and 11 the assistant takes forever to start answering. Afternoons are fine."

- TTFT p95: 0.9 s in the afternoon, 14 s at 9:30. ITL p95 stable at 35 ms.
- `vllm:num_requests_waiting`: 0 in the afternoon, 20–40 at 9:30.
- `vllm:kv_cache_usage_perc`: 0.99 at 9:30.
- 2 replicas, fixed. Autoscaling not configured.

<details><summary>Solution</summary>

**Diagnosis:** TTFT only, with queueing and a full KV cache at the morning peak: the **memory ceiling**. Requests wait for cache to free up. ITL is fine because the running batch is not larger, the extra requests are waiting outside it.

**Next check:** requests in flight at the peak against capacity per replica (from the benchmark), and prompt lengths at the peak (did a team start sending longer prompts in the morning?).

**Fix:** more capacity at the peak: a third replica on a cron schedule from 8:30 (cold start is minutes, note 24), or `--kv-cache-dtype fp8` to double the cache per replica. Autoscale on waiting requests for the unplanned part.

**To the customer:** "At the 9:30 peak there are about twice as many requests in flight as two replicas hold, so new ones wait up to 14 s. We'll add capacity from 8:30 on working days and enable FP8 KV cache; the target is TTFT p95 under 3 s at the peak, and you'll see it on the dashboard from Monday."

**Equations:** 1, 2, 5.
</details>

---

## Case 2 · "Some requests take 10 seconds to start"

> "Most answers start instantly, but some take 8–10 seconds before anything appears. No pattern."

- TTFT p50 0.4 s, p99 9 s. Queue time p99 0.2 s.
- KV usage 0.55. Waiting 0.
- Gateway logs: prompt tokens p50 1,800, p99 95,000. The slow requests all come from one key: `rag-legal`.

<details><summary>Solution</summary>

**Diagnosis:** prefill-bound requests: very long prompts from one RAG application. Queue time is flat and the cache is half empty, so it is not capacity.

**Next check:** does `rag-legal` really need 95k tokens of context, or does it paste whole documents? Prefix cache hit rate for that key (same documents repeated?).

**Fix:** with the application owner: retrieve fewer and smaller chunks. On the platform: prefix caching keeps repeated documents warm; chunked prefill (default in recent vLLM) stops these prefills from freezing other users; if long-context traffic grows, a separate replica for it. A gateway limit on max input tokens for that key protects everyone else.

**To the customer:** "The slow requests are the legal search sending about 95,000 tokens each; reading that much takes several seconds on any GPU. Cutting the retrieved context to around 20,000 tokens brings them under 2 seconds. Other users are not affected."

**Equations:** 4; also 3 (those requests slow everyone's decode a little).
</details>

---

## Case 3 · "The benchmark promised 100"

> "Your benchmark said one replica handles 100 concurrent requests. In production it chokes at 30."

- Benchmark: `--dataset-name random --random-input-len 1024 --random-output-len 128`.
- Production, from gateway logs: prompt p50 14,000 tokens, p95 38,000; output p50 900.
- Production at 30 in flight: KV usage 1.0, preemptions rising.

<details><summary>Solution</summary>

**Diagnosis:** the benchmark did not look like the traffic. KV per request in production is ~15× larger (14k+ against 1.1k tokens), so the memory ceiling is ~15× lower. Nothing is broken.

**Next check:** re-run the sweep with production lengths (p50 and p95) and with a shared prefix if their agents use one.

**Fix:** a new capacity number from the realistic benchmark; then decide between more replicas, FP8 KV and capping context.

**To the customer:** "Our benchmark used 1,000-token prompts; yours average 14,000, which is why capacity is lower. We have re-run it with your real lengths: one replica holds about 30. We were wrong to quote the earlier figure without your traffic profile; from now on every capacity number comes with the prompt lengths it assumes."

**Equations:** 1, 2. Lesson of note 21.
</details>

---

## Case 4 · "It won't start after the upgrade"

> "We upgraded to the new model version with 128k context. The pod crash-loops on the same 2 × H100."

- Logs end with something like: *"To serve at least one request with the model's max seq len (131072), 40 GiB KV cache is needed, which is larger than the available KV cache memory (31 GiB)… Try increasing `gpu_memory_utilization` or decreasing `max_model_len`."*

<details><summary>Solution</summary>

**Diagnosis:** at start-up vLLM checks that at least one request of the maximum length fits in the KV cache. The new version defaults to 128k context, and one 128k request does not fit next to the weights.

**Fix:** set `--max-model-len` to what the users actually need (32k or 64k), or `--kv-cache-dtype fp8`, or more GPUs (TP=4). Raising `--gpu-memory-utilization` from 0.9 to 0.95 gains little and risks out-of-memory errors.

**To the customer:** "The new version allows 128k-token requests by default, and the current servers cannot hold even one of those alongside the model. We've set the limit to 64k, which covers 99.9 % of your requests; if you need 128k, it means more GPUs per replica."

**Equations:** 1, 2.
</details>

---

## Case 5 · "The answers got worse"

> "Since last week the model writes worse Spanish and makes more mistakes in code. Did you change something?"

- Deploy log: last week the model was switched from the BF16 checkpoint to a community FP4 checkpoint to fit on fewer GPUs.
- Latency and errors: unchanged or better.

<details><summary>Solution</summary>

**Diagnosis:** quality regression from quantization. Metrics will never show it: latency got better.

**Next check:** run the same evaluation set on both checkpoints (their own tasks: Spanish, code), not a generic leaderboard.

**Fix:** roll back, or move to an official FP8 checkpoint (usually close to BF16), and add an eval gate to model changes: no new checkpoint in production without passing the customer's eval set.

**To the customer:** "Yes: last week we moved to a 4-bit version of the model to use fewer GPUs, and it is measurably worse on Spanish and code. We have rolled back today. From now on any change of model version or precision goes through an evaluation on your own tasks before it reaches you."

**Lesson:** changes that only improve the dashboards can still hurt users. Note 06, note 26 ("questions customers forget").
</details>

---

## Case 6 · "Buy more GPUs?"

> "GPU utilisation is at 100 % all day. We want to double the GPUs. Can you confirm?"

- `DCGM_FI_DEV_GPU_UTIL` ≈ 100 %.
- `vllm:num_requests_running`: 3–6. Waiting: 0. KV usage: 0.08.
- Throughput: 400 tokens/s. Their benchmark on the same node reached 5,000 at 64 concurrent.
- Their batch job processes 2 million documents with a Python loop, one request at a time.

<details><summary>Solution</summary>

**Diagnosis:** the **demand** ceiling. GPU utilisation means "a kernel was running", not "the GPU is full". With 3–6 requests in flight, the server is mostly idle; the batch job is sequential.

**Fix:** make the client concurrent (64 parallel requests, or vLLM's offline batch API for bulk jobs). No new GPUs.

**To the customer:** "The GPUs are not full: they are serving 3–6 requests at a time, and they can take about 60. The 100 % figure counts any activity, not capacity. If the batch job sends 64 requests in parallel it should go about ten times faster on the hardware you have. Let's try that before buying anything."

**Equations:** 3 (batching is nearly free), 5. Note 22, "GPU utilisation lies".
</details>

---

## Case 7 · "Random errors since Tuesday"

> "Since Tuesday about 1 in 20 requests fails with a 500, then it works on retry."

- Gateway: 5xx rate 4–6 %, all to the same backend, replica `qwen-1`. `litellm_deployment_state` flaps between 0 and 1.
- `qwen-1` restarted 14 times since Tuesday. Node: `DCGM_FI_DEV_XID_ERROR` = 79 on GPU 3 at each restart.
- `qwen-0` on another node: fine.

<details><summary>Solution</summary>

**Diagnosis:** hardware. XID 79 means the GPU fell off the bus. Every restart lands on the same node and the same faulty GPU.

**Fix:** cordon and drain the node, let Karpenter replace it, open a ticket with the cloud provider if it recurs. Add the `GPUXidError` alert so it pages next time instead of being found by users.

**To the customer:** "One of the GPUs in one of our two servers has a hardware fault; requests that landed on it failed. We've taken that server out and replaced it. Your retries worked because the second server was healthy, which is why we always run two."

**Note:** 23 (XID errors), 24 (minReplicaCount 2).
</details>

---

## Case 8 · "We are blocked, the model is down"

> "Our team gets errors all afternoon. Other teams say it works. Is our model down?"

- Gateway: `litellm_proxy_failed_requests_metric_total` for team `data-eng`, `exception_status="422"`, `exception_class="BudgetExceededError"`.
- `litellm_remaining_team_budget_metric{team_alias="data-eng"}` = 0 since 13:10.
- vLLM: KV usage 0.4, waiting 0.

<details><summary>Solution</summary>

**Diagnosis:** **policy**. Their monthly budget ran out at 13:10; the gateway answers 422 `budget_exceeded` (a rate limit would be 429). The model is healthy.

**Next check:** what consumed it: a new job, an agent in a loop? Spend per key over the last days.

**Fix:** a decision for whoever owns budgets (raise it, or stop the runaway job), not for the platform team. Add the `InferenceBudgetAlmostSpent` ticket alert so the team hears about it at 90 %, not at 100 %.

**To the customer:** "The model is working; your team's monthly budget was used up at 13:10, mostly by the `nightly-summarizer` key since Monday. If you want to continue, your budget owner can raise it; we'll also warn you at 90 % from now on."

**Note:** 22 (gateway layer), 25 (policy ceiling).
</details>

---

## Case 9 · "Long sessions get slow"

> "When an agent session has been running for a while, the text starts coming out slowly. New sessions are fast."

- ITL p95 rises from 30 ms to 90 ms in the afternoon. TTFT p95 fine.
- KV usage 0.7, waiting 0, running 40–50.
- Prompt tokens p50 grow from 8k in the morning to 45k in the afternoon (agents accumulate history).

<details><summary>Solution</summary>

**Diagnosis:** the **speed** ceiling. Each decode step reads the KV of every running request; as sessions accumulate 45k tokens, every step reads far more bytes, so streaming slows for everyone in the batch. Memory still has room, so nothing waits.

**Fix:** on the platform: cap `--max-num-seqs` so the batch stays within the ITL target (some requests will wait instead), FP8 KV (fewer bytes to read), more replicas. On the client: context compaction in the agent (summarise old turns), which is the biggest win.

**To the customer:** "Long agent sessions carry their whole history in each request, and reading it slows token generation for everyone. Two changes: we limit how many requests run together so streaming stays above 20 tokens/s, and we recommend enabling history compaction in the agent, which cuts the problem at the source."

**Equations:** 3, 2.
</details>

---

## Case 10 · "Autoscaling did nothing"

> "Traffic spiked at 10:00, the autoscaler fired, and users still waited 20 minutes. What's the point?"

- KEDA scaled the Deployment from 2 to 4 at 10:01.
- New pods: `Pending` until 10:14 (`0/12 nodes are available: insufficient nvidia.com/gpu`), then `ContainerCreating` until 10:19, then not Ready until 10:26.
- Model server logs: downloading weights from Hugging Face at 10:19–10:25.

<details><summary>Solution</summary>

**Diagnosis:** cold start. 13 min to get a GPU node (capacity in the AZ), 5 min to pull the image, 7 min downloading weights from the internet. The scaling signal was right; the system cannot react in less than ~25 minutes.

**Fix:** pre-stage weights near the nodes (in-region object storage with a streaming loader, or a node cache), pre-pull the image, keep a warm spare GPU node or reserved capacity, and scale ahead of known peaks with a schedule. Alert on GPU pods Pending > 15 min.

**To the customer:** "The extra servers were requested at 10:01 but took 25 minutes to be ready: finding a free GPU took 13 of them, and loading the model 12 more. We're cutting the loading time to about 3 minutes and keeping capacity ready ahead of your usual peaks, so the next spike is absorbed by servers already running."

**Note:** 24.
</details>

---

## Case 11 · "Can we run it on our L40S?"

> "We already have a server with 4 × L40S. Can we run Qwen3 235B on it for 50 developers?"

- No metrics: a design question.

<details><summary>Solution</summary>

**Reasoning:** `python3 inference/tools/fit.py --model qwen3-235b-a22b --gpu l40s --count 4`. In FP8, 235 GB of weights against 4 × 48 × 0.9 ≈ 173 GB: **it does not fit**. In FP4 (~118 GB) it loads, but L40S has no native FP4, there is little room for KV cache, and tensor parallelism runs over PCIe (no NVLink), so every token pays for it.

**Questions to ask back:** do they need 235B, or would a 30B-class MoE or a 32B dense model pass their eval? How long are their prompts? Is an 8-GPU node an option?

**To the customer:** "Not in a useful way: in its standard 8-bit form the model needs more memory than the four cards have, and the 4-bit form would load but serve only a few developers at a time, slowly. Two options: a smaller model that fits comfortably (we can compare quality on your tasks first), or one 8-GPU H200 or B200 class server."

**Note:** 19, 26.
</details>

---

## Case 12 · "Self-hosting costs three times more than the API"

> "Finance says our self-hosted model costs 3× more per token than the equivalent API. Is something wrong?"

- 2 nodes of 8 × H100, running 24/7.
- Average throughput over the month: 600 output tokens/s. Benchmark capacity: about 6,000 tokens/s per node at target latency.
- Traffic: working hours only, nearly zero at night and at weekends.

<details><summary>Solution</summary>

**Diagnosis:** utilisation. The fleet can produce ~12,000 tokens/s and averages 600: 5 %. Equation 6 divides the node price by the tokens actually produced, so cost per token is ~20× higher than at full load.

**Fix:** match capacity to demand: scale to one node out of hours (keep two at the peak for availability), move batch work to the night, consider reserved pricing only for the base load, and route low-volume models to an external API.

**To the customer:** "Nothing is broken: the servers are paid for 24 hours a day but are used about 5 % of the time on average. Scaling down at night and weekends and moving batch jobs into those hours should cut the cost per token by more than half; whether self-hosting wins after that depends mostly on your volume, and we can model it with your numbers."

**Equation:** 6.
</details>
