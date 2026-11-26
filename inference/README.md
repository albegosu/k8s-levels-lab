# Inference notes

[Español](README.es.md)

Short notes on serving LLMs: one concept per note, readable in about 15 minutes, each with something to try and three questions to check yourself. Read them in order: each builds on the ones before. You do not need the kind cluster for them.

## What this path is for

Not a list of answers. Inference customers will bring questions and problems nobody has written down yet. The path builds the three abilities you need for them:

1. **Understand** how a model is served, down to memory, bandwidth, compute and queues (phases 1 and 2).
2. **Reason** from a few equations to an answer you have never seen, and know which questions to ask first (phase 3, starting with [note 18](notes/18-first-principles.md)).
3. **Practise** estimating, diagnosing and explaining, on paper and blind, before a customer is waiting ([practice](practice/README.md)).

Phase 3 covers what operators get asked: does model X fit on an H100 or a B300, how much concurrency, how it changes with the model and the GPU, what to watch, what to alert on, how to scale. But each note shows the reasoning, so the same method works for the next model and the next GPU.

Tools: [`fit.py`](tools/fit.py), a calculator for fit and concurrency, and a [`PrometheusRule`](manifests/prometheusrule-inference.yaml) with the alerts of note 23.

```bash
python3 inference/tools/fit.py --model qwen3-235b-a22b            # fit and concurrency on every GPU
python3 inference/tools/fit.py --model llama-3.1-70b --gpu b300   # one GPU in detail
```

## Path

| Phase | Notes | Concepts | Main source |
| --- | --- | --- | --- |
| 1 · What serving a model means | 01–08 | weights and parameters, tokens (prompt vs completion), prefill vs decode, VRAM and model size, quantization, context window, the OpenAI-compatible API | [Fast & Efficient LLM Inference with vLLM](https://learn.deeplearning.ai/courses/fast-and-efficient-llm-inference-with-vllm) (DeepLearning.AI + Red Hat, 1 h 38 min) |
| 2 · Why it is fast or slow | 09–17 | what matters in a GPU, GPU instances on AWS, KV cache, PagedAttention, continuous batching, prefix caching, latency vs throughput, tensor parallelism, sizing | Same course + [vLLM docs](https://docs.vllm.ai/) |
| 3 · Reasoning and operating | 18–27 + [practice](practice/README.md) | the six equations behind every answer, does it fit on which GPU, concurrency and its two ceilings, how model and GPU change it, benchmarking, the four layers of metrics, what to alert on, scaling and cold starts, a troubleshooting method, asking customers the right questions, a full sizing journey; 12 blind cases and 16 estimation drills | [vLLM docs](https://docs.vllm.ai/), [vLLM metrics](https://docs.vllm.ai/en/latest/usage/metrics.html), [LiteLLM Prometheus](https://docs.litellm.ai/docs/proxy/prometheus), [DCGM exporter](https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/latest/dcgm-exporter.html) |
| 4 · The gateway and beyond | coming | LiteLLM in depth (virtual keys, budgets, rate limits, fallbacks, routing), disaggregated and distributed serving (llm-d, prefill/decode split, wide expert parallelism), model quality and evals after quantization | [LiteLLM proxy docs](https://docs.litellm.ai/docs/proxy/deploy), [llm-d](https://llm-d.ai/) |

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
| 18 | [First principles: six equations behind every answer](notes/18-first-principles.md) |
| 19 | [Does model X fit on GPU Y?](notes/19-does-it-fit.md) |
| 20 | [How many users can it serve?](notes/20-how-many-users.md) |
| 21 | [Measure it: the concurrency sweep](notes/21-benchmark.md) |
| 22 | [Visibility: what to look at](notes/22-visibility.md) |
| 23 | [What to alert on](notes/23-what-to-alert-on.md) |
| 24 | [Scaling and capacity on Kubernetes](notes/24-scaling.md) |
| 25 | [A method for "it is slow" and "it fails"](notes/25-troubleshooting-method.md) |
| 26 | [Asking the right questions, and answering them](notes/26-asking-the-right-questions.md) |
| 27 | [Journey: 200 developers, H100, H200 or B300?](notes/27-journey-h100-or-b300.md) |
| — | [Practice: drills and blind cases](practice/README.md) |

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

## Hands-on: level 10

[Level 10](../level-10/README.md) runs the whole path on the kind cluster, on CPU, with a small model: a llama.cpp model server with the same `/v1/chat/completions` contract as vLLM, a LiteLLM gateway with Postgres, two tenants with rate limits and budgets, a fallback, Prometheus metrics, a Grafana dashboard, alerts, and five faults to diagnose blind with note 25. What kind cannot teach (GPUs, real throughput, tensor parallelism) stays in notes 19–24.
