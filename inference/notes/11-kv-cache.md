# KV cache

**In one line:** the attention keys and values of the tokens already processed, kept in GPU memory so each new token does not recompute them.

- Size per token = 2 (key and value) × layers × KV heads × head size × bytes. For Llama 3.1 8B in FP16: 2 × 32 × 8 × 128 × 2 = 128 KiB per token, so 1 GiB for one request of 8,192 tokens.
- It grows with context length × concurrent requests. It, not the weights, usually decides how many users fit on a GPU.
- When it is full, new requests wait in the queue or running ones get preempted.
- What to watch: `vllm:kv_cache_usage_perc` near 1.
- Try it: `curl -s localhost:8000/metrics | grep kv_cache_usage`

Source: [vLLM metrics](https://docs.vllm.ai/en/latest/design/metrics.html)
