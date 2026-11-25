# What matters in a GPU for inference

**In one line:** three numbers decide how a GPU serves a model: memory size, memory bandwidth and compute, and each phase of a request leans on a different one.

## The three numbers

| Number | Unit | What it decides | Phase that needs it |
| --- | --- | --- | --- |
| **Memory size** | GB | Which models fit at all, and how much KV cache is left for users | Both |
| **Memory bandwidth** | GB/s or TB/s | How fast each decode step reads the weights: tokens per second | Decode (note 04) |
| **Compute** | TFLOPS | How fast a long prompt is processed: time to first token | Prefill (note 04) |

Marketing usually leads with compute (TFLOPS). For serving language models, **memory and bandwidth matter more**, because most of the time is spent in decode.

## Worked example: the speed limit of decode

Each decode step reads all the weights once. So for a single user, the best possible speed is roughly:

```
tokens per second  ≈  memory bandwidth  ÷  size of the weights
```

For an 8B model in BF16 (16 GB of weights), with approximate bandwidths from NVIDIA's spec sheets:

| GPU | Memory | Bandwidth | Upper bound, one user |
| --- | --- | --- | --- |
| L4 | 24 GB | about 300 GB/s | about 19 tokens/s |
| A10G | 24 GB | about 600 GB/s | about 37 tokens/s |
| L40S | 48 GB | about 860 GB/s | about 54 tokens/s |
| H100 SXM | 80 GB | about 3,350 GB/s | about 210 tokens/s |

Real numbers are lower (overheads), but the ranking holds. Two lessons:

- **Quantization speeds up decode** (note 06): FP8 weights are half the bytes, so the bound roughly doubles.
- **Batching is free speed** (note 13): one read of the weights can produce a token for many users at once, so total throughput is far higher than the one-user bound.

## Try it

Open the spec sheets of the L4 and the H100 and find memory, bandwidth and FP16 TFLOPS. Compute the ratio of bandwidth and of TFLOPS between them. Which ratio is bigger, and what does that tell you about long prompts against long answers?

## Check yourself

<details><summary>1. A 70B model in FP8 (70 GB) on an H100 (about 3,350 GB/s). Upper bound for one user?</summary>
About 48 tokens per second.
</details>
<details><summary>2. Why can a cheap L4 be a good choice for a small model?</summary>
If the model and enough KV cache fit in 24 GB, it serves fine at low cost; its limit is speed per user, not correctness.
</details>
<details><summary>3. Which number would you check first for a chat product with long answers?</summary>
Memory bandwidth, because long answers are decode-bound.
</details>

## Read more (15 min)

- [Making Deep Learning Go Brrrr From First Principles](https://horace.io/brrr_intro.html): read "Compute" and "Bandwidth". The clearest explanation of compute-bound against memory-bound.
- [Databricks: LLM inference performance engineering](https://www.databricks.com/blog/llm-inference-performance-engineering-best-practices): "What is Model Bandwidth Utilization (MBU)?".
