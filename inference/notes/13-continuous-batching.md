# Continuous batching

**In one line:** the server adds new requests to the running batch at every step, instead of waiting for the whole batch to finish.

- Batching exists because decode is limited by memory bandwidth: reading the weights once and producing a token for many requests costs almost the same as for one.
- Static batching waits for the longest request in the batch; short ones finish and leave the GPU idle.
- Continuous batching fills each freed slot right away. Anyscale measured up to 23× more throughput than naive serving, with lower median latency.
- vLLM does this by default. The limits are the KV cache and `--max-num-seqs`.
- What to watch: `vllm:num_requests_running` (in the batch) against the requests waiting.

Source: [How continuous batching enables 23x throughput (Anyscale)](https://www.anyscale.com/blog/continuous-batching-llm-inference)
