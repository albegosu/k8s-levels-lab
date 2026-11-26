# Journey: 200 developers, one model, H100, H200 or B300?

**In one line:** the whole of phase 3 on one real question, from "does it fit" to "what pages me at 3 a.m.", in the order you would answer it for a customer.

## The request

> We want Qwen3 235B-A22B as the model behind our coding agent, for 200 developers, on AWS. Contexts up to 32k tokens. What do we need, and what will it cost?

## 1. Agree the targets first

| Target | Value | Why |
| --- | --- | --- |
| TTFT p95 | < 3 s | Agents send long prompts; developers tolerate a short wait |
| ITL p95 | < 50 ms | 20 tokens/s or faster: reading speed for code |
| Errors | < 1 % | |
| Availability | Survives losing one replica | A developer tool that stops blocks 200 people |

Without these, any answer is "it depends". With them, every step below is a calculation.

## 2. Estimate the load (note 20)

Peak in flight ≈ 25 % of developers for agents ⇒ **50 requests**. Plan capacity at 65 % utilisation ⇒ **about 75 concurrent slots**, in **at least 2 replicas**.

Write the assumption down: after the first week, replace it with the measured peak of `sum(vllm:num_requests_running)`.

## 3. Does it fit, and how many per replica? (notes 19, 20)

FP8 weights (235 GB), FP8 KV cache, 32k tokens per request:

```bash
python3 inference/tools/fit.py --model qwen3-235b-a22b --gpu h100 --count 8 --ctx 32768 --kv fp8
```

| Node (8 GPUs) | Layout | Requests per replica | Replicas per node | Slots per node |
| --- | --- | --- | --- | --- |
| p5 · 8 × H100 | TP=4 | 14 | 2 | 28 |
| p5 · 8 × H100 | TP=8 | 103 | 1 | 103 |
| p5en · 8 × H200 | TP=4 | 83 | 2 | 166 |
| p6-b300 · 8 × B300 | TP=2 | 85 | 4 | 340 |
| p6-b300 · 8 × B300, **FP4 weights** | TP=2 | 122 | 4 | 488 |

Two things jump out:

- **On H100, TP=8 serves almost 4× more than two TP=4 replicas.** Two replicas each keep a full copy of the 235 GB of weights; one replica uses that memory for KV cache instead. Replicas buy availability, not capacity, when memory is tight.
- **One B300 node holds 4 replicas** with room for 340 slots: 4–5× what 200 developers need.

## 4. Choose (cost per slot, and failure domains)

| Option | Nodes | Slots | Replicas | Survives losing… |
| --- | --- | --- | --- | --- |
| A · 2 × p5 (TP=8 each) | 2 | 206 | 2 | one node |
| B · 1 × p5en (TP=4 × 2) | 1 | 166 | 2 | one replica, not the node |
| C · 1 × p6-b300 (TP=2 × 4) | 1 | 340 | 4 | one replica, not the node |
| D · ¼ of a p6-b300 shared with other models (TP=2 × 1, plus a second elsewhere) | shared | 85 + 85 | 2 | depends on placement |

Cost per slot = node price per hour ÷ slots. Use your region's on-demand or reserved price. The decision usually reads like this:

- **Only this model, only 200 developers:** B (one H200 node) is the cheapest that meets the targets with two replicas. Add a second node later if losing the node for 15 minutes is unacceptable (then A or 2 × B).
- **More teams coming, or several models:** C. A B300 node costs a multiple of an H100 node, but serves 3–4× more per node; it only wins if you **fill** it. Splitting it (D) between this model and others is how you fill it.
- **Check availability before you fall in love with a GPU:** P5 and newer need quota and often a Capacity Block or reservation (note 10).

## 5. Prove it (note 21)

Benchmark the chosen layout with real prompt lengths (p50 and p95 from the gateway logs) and a shared system prompt. Sweep concurrency, find the knee under the targets, and write the line: `model, FP8, KV fp8, B300 × 2, TP=2, vLLM x.y, knee at N, TTFT p95, ITL p95`. If the knee is far from the estimate, recalibrate `fit.py` and redo step 4.

## 6. Make it visible (note 22)

Dashboard rows: users (TTFT, ITL, errors, waiting) → fullness (KV, running, preemptions) → work (tokens/s, prefix hits) → who (spend per team) → hardware (DCGM).

## 7. Decide what wakes someone up (note 23)

Apply [`prometheusrule-inference.yaml`](../manifests/prometheusrule-inference.yaml) with these SLOs. Pages: TTFT, ITL, gateway errors, backend down, fatal XID. Tickets: queueing, KV full, preemptions, budgets, Pending GPU pods.

## 8. Scale and survive (note 24)

`minReplicaCount: 2`, KEDA on `vllm:num_requests_waiting`, a cron trigger for working hours, weights pre-staged near the nodes, and a GPU NodePool with limits.

## The answer, in one paragraph

*"Qwen3 235B in FP8 serves your 200 developers on one 8 × H200 node as two replicas, with about 3× the peak we expect; one 8 × B300 node would serve 4–5× more and makes sense if other teams or models will share it. We will confirm with a benchmark on your prompts before committing, and we alert on latency against these targets, not on GPU usage."*

## Check yourself

<details><summary>1. Why not run one TP=8 replica on a single p5 and call it done?</summary>
It meets capacity (103 slots), but one replica is one failure: a GPU fault or a redeploy stops 200 developers for the cold start.
</details>
<details><summary>2. The measured peak after a month is 120 in flight, not 50. Which option still works?</summary>
A (206 slots) at 58 %, and C (340). B (166) would run at 72 %: past the headroom target, so add a node or move to C.
</details>
<details><summary>3. Which single setting change gave the biggest jump in slots per node on B300?</summary>
FP4 weights: they halve the weight memory and leave it to KV cache (340 → 488). Native on Blackwell; check the quality of the FP4 checkpoint first.
</details>

## Read more (15 min)

- [vLLM recipes](https://recipes.vllm.ai/): the pages for Qwen3 and DeepSeek, with recommended flags per GPU.
- [Amazon EC2 P6 instances](https://aws.amazon.com/ec2/instance-types/p6/): the p6-b200 and p6-b300 specifications.
