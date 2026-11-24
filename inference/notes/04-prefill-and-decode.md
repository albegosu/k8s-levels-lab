# Prefill and decode

**In one line:** prefill processes the whole prompt in parallel and produces the first token; decode then generates the rest one token per step.

- Prefill is compute-bound: it keeps the GPU's cores busy. Long prompts mean a long wait before the first token.
- Decode is memory-bandwidth-bound: each step reads all the weights from GPU memory to make one token.
- The two latency numbers that matter come from here: **TTFT** (time to first token, mostly prefill) and **ITL** (inter-token latency, decode).
- Why it matters for a platform: batching many users' decode steps together is how one GPU serves many people (phase 2).

Source: [Databricks, LLM inference performance engineering](https://www.databricks.com/blog/llm-inference-performance-engineering-best-practices)
