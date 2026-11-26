# How many users can it serve?

**In one line:** concurrency has two ceilings, the **memory** for KV cache and the **speed** you promised users, and the lower of the two is your capacity per replica; then Little's law turns it into users.

## Two ceilings

| Ceiling | Question | Set by | What you see when you hit it |
| --- | --- | --- | --- |
| **Memory** | How many requests' KV cache fits? | KV room ÷ KV per request (notes 11, 19) | `vllm:kv_cache_usage_perc` near 1, requests waiting, preemptions |
| **Speed** | How many requests before each user gets tokens too slowly? | Bandwidth: every decode step reads the weights **and** the KV cache of every request in the batch (note 09) | Inter-token latency p95 above target, while memory still has room |

```
decode step time ≈ (weights read + batch × KV per request) ÷ bandwidth  +  fixed overhead
```

The first term barely grows with the batch (that is why batching is cheap, note 13). The second grows linearly: with long contexts, the KV reads end up dominating, and that is where the speed ceiling comes from.

`fit.py` prints both:

```bash
python3 inference/tools/fit.py --model llama-3.1-70b --gpu h100 --count 2 --ctx 8192
#   memory limit:  25 requests
#   speed limit:   25 requests keep ITL under 50 ms
```

## Concurrent requests are not users: Little's law

```
requests in flight  =  arrival rate  ×  time each request stays
```

A developer with a coding agent is not generating all the time: they read, type, run tests. If at peak 200 developers send 2 requests per second in total, and each takes 25 s end to end, there are **50 requests in flight**. Measure the real ratio once you have traffic: peak `sum(vllm:num_requests_running)` against active users in the gateway.

Rules of thumb before you have data: chat users ≈ 5–10 % in flight at peak; coding agents ≈ 20–30 %, because each turn makes several long calls.

## How it changes with the model

KV cache for **one request of 32k tokens** (BF16 cache), from each `config.json`:

| Model | Attention | KV per 32k request | Why |
| --- | --- | --- | --- |
| Llama 3.1 8B | GQA, 8 KV heads, 32 layers | 4 GiB | Few layers |
| Qwen3 32B | GQA, 8 KV heads, 64 layers | 8 GiB | Twice the layers |
| Llama 3.3 70B | GQA, 8 KV heads, 80 layers | 10 GiB | Many layers |
| Qwen3 235B-A22B | GQA, **4** KV heads, 94 layers | 6 GiB | Half the KV heads: a big model with a smaller cache than 70B |
| DeepSeek V3 | **MLA**, one 576-wide latent per layer | 2.1 GiB | The cache is compressed by design |
| gpt-oss-120b | GQA, half the layers with a **128-token sliding window** | 1.1 GiB | Half the layers forget everything beyond 128 tokens |

So "bigger model ⇒ fewer users" is wrong. The architecture decides: an MoE with MLA or sliding windows can serve **more** concurrent long requests than a dense 70B on the same memory. And MoE models decode fast for their size because each token reads only the active experts, until the batch is big enough to touch all of them.

## How it changes with the GPU

Llama 3.3 70B FP8, 32k tokens per request:

| Setup | KV room | Memory limit | Note |
| --- | --- | --- | --- |
| 2 × H100 | 69 GB | 6 requests | TP=2 |
| 1 × B300 | 187 GB | 17 requests | No TP; about 3× the users with half the GPUs |

- **More memory per GPU** raises the memory ceiling (B300 vs H100).
- **More bandwidth** raises the speed ceiling and the speed per user (H200 and Blackwell vs H100).
- **Native FP8/FP4** lets you shrink weights and cache *without* slowing down: `--kv-cache-dtype fp8` doubles the memory ceiling on Hopper and Blackwell.

## How it changes with the workload

Context length is the biggest lever (note 17): the same 2 × H100 serve about 25 requests of 8k or 6 of 32k. Output length matters for the speed ceiling and for how long each request stays (Little's law). Prefix caching (note 14) lowers real usage when requests share a long system prompt. Agents are the hardest case: long contexts, many calls, and they stay long.

## Try it

```bash
python3 inference/tools/fit.py --model llama-3.1-70b --gpu h100 --count 2 --ctx 32768
python3 inference/tools/fit.py --model llama-3.1-70b --gpu h100 --count 2 --ctx 32768 --kv fp8
python3 inference/tools/fit.py --model deepseek-v3 --gpu h200 --count 8 --ctx 32768
```

Change `--itl-slo` to 30 and to 100 and see which ceiling moves.

## Check yourself

<details><summary>1. KV usage is at 60 % but p95 inter-token latency is over target. Which ceiling did you hit, and what helps?</summary>
The speed ceiling. Lower `--max-num-seqs` to cap the batch, or add replicas or bandwidth (a faster GPU). More memory would not help.
</details>
<details><summary>2. 300 developers, peak 1.5 requests/s in total, each request takes 30 s. How many in flight?</summary>
45 (1.5 × 30).
</details>
<details><summary>3. Why can Qwen3 235B-A22B hold more 32k requests per GB than Llama 70B?</summary>
It has 4 KV heads instead of 8, so about 188 KiB per token against 320 KiB, despite having more layers.
</details>

## Read more (15 min)

- [vLLM optimization and tuning](https://docs.vllm.ai/en/latest/configuration/optimization.html): "Preemption" and "Chunked Prefill": what vLLM does at each ceiling.
- [DeepSeek-V2 paper, section 2.1](https://arxiv.org/abs/2405.04434): Multi-head Latent Attention, and its KV cache table against MHA and GQA.
