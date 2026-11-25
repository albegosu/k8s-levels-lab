# Inference notes

[Español](README.es.md)

Short notes on serving LLMs: one concept per note, readable in about 15 minutes, each with something to try and three questions to check yourself. Read them in order: each builds on the ones before. You do not need the kind cluster for them.

## Path

| Phase | Notes | Concepts | Main source |
| --- | --- | --- | --- |
| 1 · What serving a model means | 01–08 | weights and parameters, tokens (prompt vs completion), prefill vs decode, VRAM and model size, quantization, context window, the OpenAI-compatible API | [Fast & Efficient LLM Inference with vLLM](https://learn.deeplearning.ai/courses/fast-and-efficient-llm-inference-with-vllm) (DeepLearning.AI + Red Hat, 1 h 38 min) |
| 2 · Why it is fast or slow | 09–17 | what matters in a GPU, GPU instances on AWS, KV cache, PagedAttention, continuous batching, prefix caching, latency vs throughput, tensor parallelism, sizing | Same course + [vLLM docs](https://docs.vllm.ai/) |
| 3 · Running it as a platform | coming | gateway (LiteLLM): virtual keys, budgets, rate limits, fallbacks; GPUs in Kubernetes (device plugin / GPU Operator, taints, GPU node pools); serving metrics; distributed serving (llm-d) | [LiteLLM proxy docs](https://docs.litellm.ai/docs/proxy/deploy), [llm-d](https://llm-d.ai/) |

## Notes

| # | Note |
| --- | --- |
| 01 | [What serving a model means](notes/01-serving-a-model.md) |
| 02 | [Tokens](notes/02-tokens.md) |
| 03 | [Prompt vs completion tokens](notes/03-prompt-vs-completion.md) |
| 04 | [Prefill and decode](notes/04-prefill-and-decode.md) |
| 05 | [VRAM and model size](notes/05-vram-and-model-size.md) |
| 06 | [Quantization](notes/06-quantization.md) |
| 07 | [Context window](notes/07-context-window.md) |
| 08 | [The OpenAI-compatible API](notes/08-openai-compatible-api.md) |
| 09 | [What matters in a GPU](notes/09-what-matters-in-a-gpu.md) |
| 10 | [GPU instances on AWS](notes/10-gpu-instances-on-aws.md) |
| 11 | [KV cache](notes/11-kv-cache.md) |
| 12 | [PagedAttention](notes/12-pagedattention.md) |
| 13 | [Continuous batching](notes/13-continuous-batching.md) |
| 14 | [Prefix caching](notes/14-prefix-caching.md) |
| 15 | [Latency and throughput](notes/15-latency-and-throughput.md) |
| 16 | [Tensor parallelism](notes/16-tensor-parallelism.md) |
| 17 | [Sizing example: a 70B model](notes/17-sizing-example.md) |

## Running the examples

The `curl` examples use two variables, `BASE_URL` and `KEY`, so they work against any OpenAI-compatible server. The simplest one is [Ollama](https://ollama.com/) on your laptop, with a small model:

```bash
brew install ollama
ollama serve &                      # listens on localhost:11434
ollama pull qwen2.5:0.5b            # about 400 MB, runs on CPU
export BASE_URL=http://localhost:11434 KEY=unused
curl -s $BASE_URL/v1/models | jq '.data[].id'
```

Use `qwen2.5:0.5b` wherever a note says `<model>`. If you have access to a LiteLLM gateway, set `BASE_URL` to it and `KEY` to your virtual key instead. Two endpoints exist only on LiteLLM: `/key/info` (note 03) and `/v1/model/info` (note 07). Against Ollama, skip those lines.

## Note format

| Section | What goes in it |
| --- | --- |
| **In one line** | The definition, in one sentence |
| **The idea** | The concept in plain words, with a small diagram or table when it helps |
| **Worked example** or **In the platform** | Real numbers, or where it shows up in LiteLLM, vLLM or agent harnesses (OpenCode, Codex…) |
| **Try it** | Something runnable: a `curl` against the server, a calculation, a page to inspect |
| **Check yourself** | Three questions, with the answers folded in `<details>` |
| **Read more** | One or two sources, naming the exact sections to read and why |

Metric names, flags and source sections were checked against the live docs when each note was written.

## Coming next: level 10

Level 10 will run the whole path on the kind cluster, on CPU, with a small model: same API and gateway as production, without the GPU.

1. **Model server:** a small model (Qwen 0.5B class) behind an OpenAI-compatible API: llama.cpp server or Ollama on CPU. Same `/v1/chat/completions` contract as vLLM.
2. **Gateway:** LiteLLM proxy with Postgres (virtual keys and budgets need it) and Redis (shared rate limits once there is more than one replica).
3. **Tenants:** two virtual keys, one with a tiny budget and a low RPM limit. Prove the limit and the budget block requests.
4. **Fallback:** a second model route; kill the first server and see LiteLLM fail over.
5. **Metrics:** scrape the gateway and the model server into the level 8 Prometheus; Grafana panel with latency, tokens/s and spend per key.
6. **Faults to find blind (like level 9):** budget exhausted, model server OOMKilled, wrong model name in the route, Postgres down.

What kind cannot teach here: GPU scheduling, the device plugin, MIG and real throughput. Those stay as notes in phase 3.
