# Quantization

**In one line:** storing the weights with fewer bits (8 or 4 instead of 16) so the model takes less memory and decodes faster, at some cost in quality.

- FP8 halves the weight memory with little quality loss on recent GPUs. INT4 methods (AWQ, GPTQ) cut it to about a quarter.
- Smaller weights also mean less to read on every decode step, so tokens come out faster.
- The trade-off is quality, and it depends on the model and the task: always check with your own prompts, not only benchmarks.
- What to check: which formats your GPUs and vLLM support (`--quantization`), and whether the checkpoint is already quantized.

Source: [vLLM quantization](https://docs.vllm.ai/en/latest/features/quantization/)
