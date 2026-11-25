# Sizing example: a 70B model

**In one line:** put notes 05, 06, 10, 11 and 16 together to estimate how many users one deployment serves.

## The question

A customer wants a 70B model (Llama 3.1 70B class) for a coding-agent platform. How many people can use it at once on two H100s?

## Step by step

**1. Weights (notes 05 and 06).** In FP8, 1 byte per parameter: about **70 GB**.

**2. GPU memory (notes 10 and 16).** Two H100s with `--tensor-parallel-size 2`: 160 GB. vLLM uses 90 % by default (`--gpu-memory-utilization 0.9`): **144 GB**.

**3. Room for KV cache.** 144 − 70 = **about 74 GB** (a bit less in reality: activations and CUDA graphs take some).

**4. KV cache per token (note 11).** 80 layers, 8 KV heads, head size 128, FP16:
2 × 80 × 8 × 128 × 2 bytes = **320 KiB per token**.

**5. Capacity.** 74 GB ÷ 320 KiB ≈ **225,000 tokens** in cache at once.

| Context per request | Requests at once |
| --- | --- |
| 8k tokens (chat) | about 27 |
| 32k tokens (coding agent) | about 6 |
| 128k tokens (full model window) | 1 |

## What this tells you

- **Context length is the main lever.** The same hardware serves about 27 chat users or 6 agents. This is why the gateway limits context and requests per key, and why `--max-model-len` matters (note 07).
- **Cheap improvements before buying GPUs:**
  - FP8 KV cache (`--kv-cache-dtype fp8`): about 450,000 tokens, double the users;
  - prefix caching (note 14): agents share their long system prompt, so real usage is lower than the worst case;
  - not every user is mid-request at the same moment, so 6 concurrent agents can mean 20–30 people working.
- **TP=4 instead of TP=2** on four H100s: 288 GB usable, about 218 GB for cache, three times the capacity for twice the GPUs.

## Try it

Redo the steps for:

1. the same model on **four L40S** (48 GB each, TP=4);
2. an **8B model in BF16** on **one L4** (24 GB). Use 128 KiB per token from note 11.

## Check yourself

<details><summary>1. Four L40S, 70B in FP8: KV cache room and agents at 32k?</summary>
192 GB × 0.9 = about 173 GB; minus 70 GB = about 103 GB; ÷ 320 KiB ≈ 314,000 tokens; about 9 agents at 32k.
</details>
<details><summary>2. 8B in BF16 on one L4: requests of 8k at once?</summary>
24 × 0.9 = about 21.6 GB; minus 16 GB = about 5.6 GB; ÷ 128 KiB ≈ 43,000 tokens; about 5 requests of 8k.
</details>
<details><summary>3. Which single change doubles capacity without new hardware?</summary>
An FP8 KV cache: it halves the bytes per token.
</details>

## Read more (15 min)

- [vLLM optimization and tuning](https://docs.vllm.ai/en/latest/configuration/optimization.html): "GPU Memory Utilization" and "Preemption".
- [Databricks: LLM inference performance engineering](https://www.databricks.com/blog/llm-inference-performance-engineering-best-practices): "How does latency scale with tensor parallelism for MPT-7B and Llama2-70B?".
