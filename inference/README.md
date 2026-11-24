# Inference notes

Short daily notes on serving LLMs, written while learning: one concept per note, five lines and a command or a diagram. They prepare [level 10](#level-10-plan), where the concepts run on the lab cluster.

## Path

| Phase | Weeks | Concepts | Main source |
| --- | --- | --- | --- |
| 1 · What serving a model means | Nov 25 – Dec 4 | weights and parameters, tokens (prompt vs completion), prefill vs decode, VRAM and model size, quantization | [Fast & Efficient LLM Inference with vLLM](https://learn.deeplearning.ai/courses/fast-and-efficient-llm-inference-with-vllm) (DeepLearning.AI + Red Hat, 1 h 38 min) |
| 2 · Why it is fast or slow | Dec 7 – Dec 18 | GPU instances on AWS (g5, g6, p5, inf2), KV cache, PagedAttention, continuous batching, prefix caching | Same course + [vLLM docs](https://docs.vllm.ai/) |
| 3 · Running it as a platform | Dec 21 – Jan 29 | gateway (LiteLLM): virtual keys, budgets, rate limits, fallbacks; GPUs in Kubernetes (device plugin / GPU Operator, taints, GPU node pools); metrics (TTFT, inter-token latency, tokens/s, queue length, KV cache use); distributed serving (llm-d) | [LiteLLM proxy docs](https://docs.litellm.ai/docs/proxy/deploy), [llm-d](https://llm-d.ai/) |

## Notes

| # | Note | Day |
| --- | --- | --- |
| 01 | [What serving a model means](notes/01-serving-a-model.md) | Nov 25 |
| 02 | [Tokens](notes/02-tokens.md) | Nov 26 |
| 03 | [Prompt vs completion tokens](notes/03-prompt-vs-completion.md) | Nov 27 |
| 04 | [Prefill and decode](notes/04-prefill-and-decode.md) | Nov 30 |
| 05 | [VRAM and model size](notes/05-vram-and-model-size.md) | Dec 1 |
| 06 | [Quantization](notes/06-quantization.md) | Dec 2 |
| 07 | [Context window](notes/07-context-window.md) | Dec 3 |
| 08 | [The OpenAI-compatible API](notes/08-openai-compatible-api.md) | Dec 4 |

## Note format

One file per concept, `inference/notes/NN-slug.md`:

```markdown
# KV cache

**In one line:** the attention keys and values of tokens already processed, kept in GPU memory so each new token does not recompute them.

- Why it matters: it grows with context length × concurrent requests, so it, not the weights, usually decides how many users fit on a GPU.
- What to watch: `vllm:gpu_cache_usage_perc` near 1 means requests queue or get preempted.
- Try it: `curl localhost:8000/metrics | grep cache_usage`

Source: <link>
```

## Level 10 plan

Level 10 runs the whole path on kind, on CPU, with a small model. Same API and gateway as production, without the GPU.

1. **Model server:** a small model (Qwen 0.5B class) behind an OpenAI-compatible API: llama.cpp server or Ollama on CPU. Same `/v1/chat/completions` contract as vLLM.
2. **Gateway:** LiteLLM proxy with Postgres (virtual keys and budgets need it) and Redis (shared rate limits once there is more than one replica).
3. **Tenants:** two virtual keys, one with a tiny budget and a low RPM limit. Prove the limit and the budget block requests.
4. **Fallback:** a second model route; kill the first server and see LiteLLM fail over.
5. **Metrics:** scrape the gateway and the model server into the level 8 Prometheus; Grafana panel with latency, tokens/s and spend per key.
6. **Faults to find blind (like level 9):** budget exhausted, model server OOMKilled, wrong model name in the route, Postgres down.

What kind cannot teach here: GPU scheduling, the device plugin, MIG and real throughput. Those stay as notes in phase 3.
