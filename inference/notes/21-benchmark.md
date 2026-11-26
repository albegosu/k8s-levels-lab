# Measure it: the concurrency sweep

**In one line:** run your real traffic shape against one replica at rising concurrency, and the highest concurrency that still meets your latency targets is the capacity you plan with.

## Why estimates are not enough

Notes 19 and 20 tell you which setup to try. They ignore kernel quality, the vLLM version, chunked prefill, tensor-parallel traffic and how your prompts really look. Real numbers are often 30–50 % off the estimate, in either direction. You benchmark **before** quoting capacity to anyone.

## The shape of the result

```
tokens/s total          ITL p95
     ▲                    ▲
     │        ●───●───●   │                    ●
     │     ●              │                 ●
     │   ●                │  ─ ─ ─ ─ ─ ─ ─●─ ─ ─ target (50 ms)
     │ ●                  │       ●  ●
     │●                   │●  ●
     └──────────────▶     └──────────────▶
       concurrency           concurrency
                 the knee: throughput stops growing, latency starts climbing
```

You want the point just before the knee that still meets **all** targets (TTFT p95, ITL p95, errors). That is your **capacity per replica**.

## Running the sweep with vLLM

`vllm bench serve` ships with vLLM and talks to any OpenAI-compatible endpoint:

```bash
for c in 1 4 8 16 32 64; do
  vllm bench serve \
    --base-url "$BASE_URL" --model <model> \
    --dataset-name random --random-input-len 6000 --random-output-len 400 \
    --num-prompts $((c * 10)) --max-concurrency $c \
    --percentile-metrics ttft,itl,e2el --metric-percentiles 50,95 \
    --save-result --result-filename "bench-c$c.json"
done
```

Read for each run: output tokens/s, TTFT p95, ITL p95. Put them in a table and find the knee.

| What to set | How to choose it |
| --- | --- |
| Input and output lengths | From real traffic: the gateway logs prompt and completion tokens per request (LiteLLM spend logs). Use p50 and also a run at p95 lengths |
| Shared prefix | Agents repeat a long system prompt. A random dataset has no shared prefix, so it **underestimates** prefix caching (note 14). Add a run with a fixed prefix (`--dataset-name prefix_repetition`, or your own prompts) |
| Concurrency or rate | `--max-concurrency` finds capacity. `--request-rate` (Poisson arrivals) tells you how queues behave under bursts |
| Duration | At least a few minutes per step: the first requests warm caches and CUDA graphs |

[GuideLLM](https://github.com/vllm-project/guidellm) does the same sweep automatically and reports the maximum rate that meets your targets.

## Calibrate the estimator

Once you have one real result, adjust `fit.py` so the next estimates are closer:

- Single-user ITL higher than the estimate → raise `--overhead` (fixed ms per step).
- ITL grows faster with concurrency than estimated → lower `--mbu` (fraction of bandwidth reached).

Write the calibrated values next to the GPU and vLLM version. They change with both.

## What to record

One line per setup is enough for the next person to trust or redo it:

```
model, precision, KV dtype, GPU × count, TP, vLLM version, flags,
input/output lengths, concurrency at knee, tokens/s at knee, TTFT p95, ITL p95
```

## Try it

Against Ollama on your laptop (note on running the examples), run the loop with `--max-concurrency` 1, 2, 4 and 8 and short lengths (`--random-input-len 200 --random-output-len 100`). Even on CPU you will see the knee: total tokens/s stops growing and ITL climbs. If you do not have vLLM installed, `pip install vllm` installs the benchmark client too (it runs without a GPU).

## Check yourself

<details><summary>1. Throughput grows from concurrency 16 to 32, and ITL p95 goes from 35 to 70 ms with a 50 ms target. Capacity?</summary>
About 16 (or the highest step under 50 ms if you test between). Higher throughput past the target does not count.
</details>
<details><summary>2. Why does a random dataset underestimate capacity for a coding agent?</summary>
Agents share long prefixes (system prompt, tools, repository context) that prefix caching skips. Random prompts share nothing.
</details>
<details><summary>3. Your benchmark used 2k-token prompts; production p95 is 20k. What changes?</summary>
TTFT (longer prefill), KV per request (fewer fit) and the speed ceiling. Re-run with p95 lengths: capacity will be much lower.
</details>

## Read more (15 min)

- [`vllm bench serve` reference](https://docs.vllm.ai/en/latest/cli/bench/serve.html): every option, and the datasets (`random`, `prefix_repetition`, `sharegpt`…).
- [NVIDIA: LLM Inference Benchmarking, Fundamental Concepts](https://developer.nvidia.com/blog/llm-benchmarking-fundamental-concepts/): the metrics and the load parameters, concurrency against request rate.
