# Quantization

**In one line:** storing the weights with fewer bits (8 or 4 instead of 16) so the model takes less memory and decodes faster, at some cost in quality.

## The idea

Each weight is a number. In BF16 it uses 16 bits; quantization stores it in 8 or 4 bits by rounding it onto a coarser scale. You lose some precision, but:

- **less memory:** half (8-bit) or a quarter (4-bit) of the BF16 size (note 05), which leaves more room for KV cache and users;
- **faster decode:** each decode step reads all the weights (note 04), so fewer bytes means faster tokens.

## The formats you will meet

| Format | Bits | Where it fits |
| --- | --- | --- |
| **FP8** | 8 | The default choice on recent GPUs (H100, L4, L40S run it natively). Very small quality loss |
| **INT8** | 8 | Similar savings, used on GPUs without FP8 |
| **AWQ / GPTQ** | 4 | Pre-quantized checkpoints on Hugging Face. A quarter of the memory, more quality risk |
| **GGUF** | 2–8 | The llama.cpp / Ollama format, for laptops and CPUs. Not the usual choice for vLLM in production |

Two practical points:

- **Pre-quantized or on the fly.** Many models are published already quantized (look for `-FP8` or `-AWQ` in the name). vLLM can also quantize some formats at load time with `--quantization fp8`.
- **The KV cache can be quantized too:** `--kv-cache-dtype fp8` roughly doubles the tokens that fit in the cache.

## The trade-off

Quality loss depends on the model, the method and the task. Code and maths often suffer before chat does. Always check with your own prompts (for example, a handful of real tasks from your team run against both versions), not only with published benchmarks.

## Try it

On Hugging Face, search for a model you know, for example `Qwen3 32B`, and find its official `FP8` and `AWQ` versions. Compare the total file size with the original: it should be about ½ and ¼.

## Check yourself

<details><summary>1. Why does quantization speed up decode, not only save memory?</summary>
Decode is limited by reading the weights from memory; fewer bytes per weight means less to read per token.
</details>
<details><summary>2. On an H100, which format would you try first, and why?</summary>
FP8: native on that GPU, half the memory, and usually a very small quality loss.
</details>
<details><summary>3. What do you check before switching a production model to INT4?</summary>
Quality on your own real tasks (for coding agents, tasks that use tools), not just benchmark scores.
</details>

## Read more (15 min)

- [Hugging Face: quantization overview](https://huggingface.co/docs/transformers/quantization/overview): read "Two ways to use a quantized model" and "Choose a method".
- [vLLM quantization](https://docs.vllm.ai/en/latest/features/quantization/): read "Supported Hardware" to see which format runs on which GPU.
