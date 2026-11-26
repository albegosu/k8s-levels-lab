# First principles: six equations behind every answer

**In one line:** almost every question about serving a model, from "does it fit" to "why is it slow" or "why is it expensive", comes back to six back-of-the-envelope equations; learn to reach for them and you can answer questions nobody has written a note for.

## Why start here

Phase 3 is about questions you will get from customers and from incidents. You cannot memorise the answers, because the model, the GPU and the workload change every time. What does not change is the physics: memory, bandwidth, compute, and queues. The following notes all use these six equations; when you face a new question, write down which ones it touches before you answer.

## The six equations

**1. Memory budget** (notes 05, 11, 19)

```
weights + KV cache in use + reserve  ≤  GPUs × memory × 0.9
weights = total parameters × bytes per parameter        (BF16 2 · FP8 1 · FP4 0.5)
```

**2. KV cache per token** (note 11)

```
KV bytes per token = 2 × layers × KV heads × head size × bytes per value
KV per request     = KV per token × tokens in the request (prompt + answer so far)
```

**3. Decode speed: bytes read per step** (notes 09, 13, 20)

```
ITL ≈ (active weights + Σ KV of requests in the batch) ÷ bandwidth  +  fixed overhead
```

Every step reads the weights once (shared by the whole batch) and the KV cache of every request (not shared). This one equation explains why batching is cheap, why long contexts slow everybody down, and why bandwidth matters more than TFLOPS for chat.

**4. Prefill speed: compute** (note 04)

```
prefill time ≈ 2 × active parameters × prompt tokens ÷ (FLOPS × efficiency ~0.5)
TTFT         ≈ queue time + prefill time
```

Llama 70B in FP8 on 2 × H100 (about 2,000 dense FP8 TFLOPS each), 10k-token prompt: 2 × 70·10⁹ × 10⁴ ÷ (4·10¹⁵ × 0.5) ≈ **0.7 s**. Attention adds a term that grows with the square of the prompt, which starts to matter past tens of thousands of tokens.

**5. Little's law: requests in flight** (note 20)

```
requests in flight = arrival rate × time each request takes
```

**6. Cost per token**

```
cost per million tokens = node price per hour ÷ (tokens per second × 3,600) × 10⁶
```

A node at 30 $/h producing 3,000 output tokens/s costs about 2.8 $ per million tokens **at full load**. At 20 % average load, 14 $. Utilisation, not the GPU price, usually decides cost (the numbers are illustrative: use your price).

## What moves what

Read across: which equation each knob touches, and in which direction.

| Change | Memory ceiling (1, 2) | ITL (3) | TTFT (4, 5) | Cost (6) | Catch |
| --- | --- | --- | --- | --- | --- |
| Longer contexts | ↓ fewer requests fit | ↑ more KV read per step | ↑ longer prefill | ↑ | The biggest lever, often decided by the client app |
| FP8 weights (from BF16) | ↑ room for KV | ↓ half the bytes | ↓ on FP8 GPUs | ↓ | Check quality on your own evals |
| FP8 KV cache | ↑ ×2 | ↓ slightly | — | ↓ | Small quality risk |
| More GPUs, same replica (TP) | ↑ | ↓ more bandwidth | ↓ | ↑ per replica | Communication cost; stays inside one node |
| More replicas | ↑ total, same per replica | — | ↓ only if queueing | ↑ | Prefix cache split across replicas |
| Faster-memory GPU (H100 → H200/B300) | ↑ | ↓ | ↓ | depends on price per slot | Quota and availability |
| Larger batch (`--max-num-seqs`) | — | ↑ | ↓ less queueing | ↓ per token | Until it breaks the ITL target |
| Shared prefix (prefix caching) | ↑ blocks shared | — | ↓ prefill skipped | ↓ | Needs routing that keeps the prefix on one replica |
| MoE instead of dense, same total size | same | ↓ fewer active bytes (small batches) | ↓ | ↓ | Gains shrink as the batch touches every expert |

## Numbers worth knowing by heart

| Quantity | Order of magnitude |
| --- | --- |
| Bytes per parameter | BF16 2, FP8 1, FP4 0.5 |
| KV per token, 70B-class GQA model | ~300 KiB (BF16) |
| HBM bandwidth | H100 3.35 TB/s · H200 4.8 · B200/B300 8 |
| GPU memory | H100 80 GB · H200 141 · B200 180 · B300 288 |
| Dense compute | H100 ~1 PFLOPS BF16, ~2 FP8; Blackwell about twice that, plus FP4 |
| Comfortable reading speed | ~10 tokens/s; "fast" feels like 30–50+ |
| Cold start of a large model | minutes, not seconds |

## Reasoning out loud: a worked example

> "We want to raise the context limit from 32k to 64k on the same servers. What happens?"

- **Equation 2:** KV per request doubles for the requests that use it.
- **Equation 1:** the memory ceiling halves for those requests: if 50 fitted at 32k, about 25 fit at 64k.
- **Equation 3:** every step reads more KV, so ITL rises for **everyone** in the batch, not only for long requests.
- **Equation 4:** a 64k prompt takes at least twice as long to prefill, more with the attention term; while it prefills, other users' TTFT can grow too.
- **Equation 5:** long requests stay longer, so requests in flight grow, which pushes further against the ceiling.
- **Answer:** *"You can, but on the same hardware expect roughly half the concurrency for long requests and slower streaming for everybody at peak. Options: FP8 KV cache, a separate long-context pool, or more memory. We will measure it with your traffic before changing it."*

Notice the shape of the answer: the consequence, its rough size, the options, how to confirm. Note 26 works on that.

## Try it

Answer with the equations, then check with `python3 inference/tools/fit.py`:

1. A customer moves from Llama 70B BF16 to FP8 on 4 × H100. What happens to concurrency and ITL?
2. What happens to cost per token if traffic halves and you keep the same nodes?

## Check yourself

<details><summary>1. Why does one user with a 100k-token context slow down the other 30 users?</summary>
Equation 3: each decode step reads every request's KV cache, and that one request adds a lot of bytes to every step. Its prefill also takes the GPU for a while (equation 4).
</details>
<details><summary>2. Throughput doubled after a change, yet users say it is slower. How?</summary>
A larger batch raises total tokens/s (weights read once for more requests) and raises ITL for each user (equation 3). Both are true at once.
</details>
<details><summary>3. The GPU price went down 30 %, but the cost per token went up. Plausible?</summary>
Yes: equation 6 divides by tokens actually produced. If utilisation fell (less traffic, more replicas than needed), cost per token rises regardless of the price.
</details>

## Read more (20 min)

- [Making Deep Learning Go Brrrr From First Principles](https://horace.io/brrr_intro.html): the whole post. Compute-bound, memory-bound and overhead-bound, the three regimes behind equations 3 and 4.
- [Transformer inference arithmetic (kipply)](https://kipp.ly/transformer-inference-arithmetic/): "kv cache", "capacity" and "latency calculations". The same equations, derived in detail.
