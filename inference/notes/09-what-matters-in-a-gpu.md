# What matters in a GPU for inference

**In one line:** three numbers decide how a GPU serves a model: memory size, memory bandwidth and compute, and each phase of a request leans on a different one.

- **Memory size** (GB): the weights and the KV cache must fit. It decides which models you can serve at all and how many requests fit at once.
- **Memory bandwidth** (GB/s): decode reads all the weights for every new token, so it is limited by bandwidth, not by compute. This is why generation speed tracks bandwidth.
- **Compute** (FLOPs): prefill processes the whole prompt in parallel and is limited by compute. Long prompts lean on it.
- A cheaper GPU with enough memory can serve a small model well; a large model needs memory first, then bandwidth.
- Try it: compare the memory and bandwidth of an L4 and an H100 on their spec sheets, and guess which phase each one handles better.

Source: [How continuous batching enables 23x throughput (Anyscale)](https://www.anyscale.com/blog/continuous-batching-llm-inference)
