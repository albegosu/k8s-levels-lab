# Latency and throughput

**In one line:** a user feels latency, the platform pays for throughput, and a bigger batch trades one for the other.

## The metrics

| Metric | What it measures | What drives it | vLLM metric |
| --- | --- | --- | --- |
| **TTFT**, time to first token | Wait until something appears | Queue + prefill (note 04) | `vllm:time_to_first_token_seconds` |
| **ITL**, inter-token latency | Time between tokens while streaming | Decode + batch size | `vllm:inter_token_latency_seconds` |
| **End-to-end latency** | Whole request | TTFT + output tokens × ITL | `vllm:e2e_request_latency_seconds` |
| **Throughput** | Tokens per second for the whole server | Batch size, GPU, model | Rate of `vllm:generation_tokens_total` |

```
request ─▶ [queue] [prefill] ▶ tok ▶ tok ▶ tok ▶ … ▶ tok ▶ done
           └──── TTFT ─────┘   └ITL┘
           └──────────────── end-to-end latency ─────────────┘
```

## The trade-off

A bigger batch (note 13) produces more tokens per second **in total**, but each step does more work, so every user gets their tokens a bit slower. At some point, users waiting in the queue also make TTFT jump.

So you do not "maximise" either. You set targets from what users accept, and push throughput as far as those targets allow. For example, for a coding agent:

- TTFT p95 under 3 s;
- ITL p95 under 50 ms (20 tokens per second or faster).

## Measure percentiles, not averages

An average of 1 s can hide 5 % of requests taking 10 s, and those are the ones users complain about. Always look at p50 and p95 (or p99).

## Try it

If you can reach a vLLM server or its Grafana dashboard, find the TTFT and ITL histograms and read p50 against p95. Without a server, run the 10 parallel requests of note 13 and note the slowest against the fastest.

## Check yourself

<details><summary>1. Users say "it takes ages to start, then it's fast". Which metric?</summary>
TTFT: queueing or prefill. Check queue length and prompt sizes.
</details>
<details><summary>2. Why does throughput go up while each user gets slower?</summary>
Each decode step serves more requests, so total tokens per second grow, but each step takes a bit longer.
</details>
<details><summary>3. Why are averages a bad target?</summary>
They hide the slow tail. A few very slow requests barely move the average but ruin those users' experience.
</details>

## Read more (15 min)

- [NVIDIA: LLM inference benchmarking metrics](https://docs.nvidia.com/nim/benchmarking/llm/latest/metrics.html): the whole page, about 5 minutes.
- [Databricks: LLM inference performance engineering](https://www.databricks.com/blog/llm-inference-performance-engineering-best-practices): "How does batch size affect the trade-off between latency and throughput?".
