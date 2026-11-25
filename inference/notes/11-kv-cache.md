# KV cache

**In one line:** the attention keys and values of the tokens already processed, kept in GPU memory so each new token does not recompute them.

## The idea

To produce each new token, the model looks back at every previous token through **attention**. For that it needs, for every previous token and every layer, two vectors: a **key** and a **value**. Computing them again at every step would repeat almost all the work. So the server computes them once and keeps them: the **KV cache**.

```
step 1 (prefill): prompt tokens ──▶ compute K,V for all of them ──▶ store in cache ──▶ token 1
step 2:           token 1       ──▶ compute K,V for 1 token     ──▶ append        ──▶ token 2
step 3:           token 2       ──▶ …                            ──▶ append        ──▶ token 3
```

The price is memory: the cache holds K and V for every token of every active request.

## How big it is

```
bytes per token = 2 (K and V) × layers × KV heads × head size × bytes per value
```

| Model | Layers | KV heads | Head size | Per token (FP16) | One 8k request | One 32k request |
| --- | --- | --- | --- | --- | --- | --- |
| Llama 3.1 8B | 32 | 8 | 128 | 128 KiB | 1 GiB | 4 GiB |
| Llama 3.1 70B | 80 | 8 | 128 | 320 KiB | 2.5 GiB | 10 GiB |

Both models use **grouped-query attention (GQA)**: many query heads share 8 KV heads, which makes the cache 4–8 times smaller than it would be. That is one reason modern models are cheaper to serve.

## Why it matters

- **It decides how many users fit**, more than the weights. Weights are fixed; the cache grows with context length × concurrent requests.
- **When it is full**, new requests wait in the queue, and running ones can be preempted (paused and recomputed later).
- **It can be quantized:** `--kv-cache-dtype fp8` halves it (note 06).

What to watch in vLLM: `vllm:kv_cache_usage_perc` close to 1, together with requests waiting.

## Try it

- Compute the KV cache per token for a model you care about. Open its `config.json` on Hugging Face and find `num_hidden_layers`, `num_key_value_heads` and `head_dim` (or `hidden_size ÷ num_attention_heads`).
- If you have access to a vLLM server: `curl -s <server>/metrics | grep kv_cache_usage`.

## Check yourself

<details><summary>1. Why not recompute K and V at every step instead of storing them?</summary>
Each step would redo the work for every previous token, so generation would get slower with every token.
</details>
<details><summary>2. With 20 GB free for cache and Llama 3.1 8B, how many 8k requests fit at once?</summary>
About 18 (1 GiB each, and 20 GB is about 18.6 GiB).
</details>
<details><summary>3. Why does lowering `--max-model-len` let more users in?</summary>
It caps how much cache a single request can take, so the same memory is shared by more requests.
</details>

## Read more (15 min)

- [Hugging Face: KV cache from scratch](https://huggingface.co/blog/kv-cache): read "Where Redundancy Creeps In" and "How KV Caching Fixes It".
- [Databricks: LLM inference performance engineering](https://www.databricks.com/blog/llm-inference-performance-engineering-best-practices): the FAQ "What is Grouped Query Attention (GQA) and how does it help with KV cache size?".
