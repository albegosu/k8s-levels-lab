# Sizing example: a 70B model

**In one line:** put notes 05, 10, 11 and 16 together to estimate how many users one deployment serves.

- **Weights:** a 70B model in FP8 (note 06) takes about 70 GB.
- **GPUs:** two H100s (80 GB each) with `--tensor-parallel-size 2`. vLLM uses 90 % of GPU memory by default (`--gpu-memory-utilization 0.9`), so 144 GB, and about 74 GB is left for KV cache.
- **KV per token:** Llama 3.1 70B has 80 layers, 8 KV heads and heads of size 128. In FP16: 2 × 80 × 8 × 128 × 2 = 320 KiB per token.
- **Capacity:** 74 GB ÷ 320 KiB ≈ 225,000 tokens of cache: about 27 requests of 8,192 tokens at once, or about 6 agents with 32k contexts.
- Long contexts eat capacity fast; that is why the gateway limits context and requests per key.
- Try it: redo the numbers for 4 L40S (48 GB each) with `--tensor-parallel-size 4`.

Source: [vLLM optimization and tuning](https://docs.vllm.ai/en/latest/configuration/optimization.html)
