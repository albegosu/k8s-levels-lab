# VRAM and model size

**In one line:** the weights must fit in GPU memory, and their size is parameters × bytes per parameter.

## The idea

The "8B" or "70B" in a model's name is its number of parameters, in billions. Each parameter is stored with some precision, and that sets the bytes:

| Precision | Bytes per parameter | 8B model | 32B model | 70B model |
| --- | --- | --- | --- | --- |
| FP16 / BF16 | 2 | 16 GB | 64 GB | 140 GB |
| FP8 / INT8 | 1 | 8 GB | 32 GB | 70 GB |
| INT4 | 0.5 | 4 GB | 16 GB | 35 GB |

That is **only the weights**. GPU memory (VRAM) also holds:

- the **KV cache** (note 11): the memory of every active request. This is what decides how many users fit;
- activations and the server's own overhead: a few GB.

```
GPU memory, e.g. 80 GB
┌───────────────────────────────┬──────────────────────────────┬────┐
│ weights (fixed)               │ KV cache (shared by requests)│ ~  │
└───────────────────────────────┴──────────────────────────────┴────┘
                                  more room here = more users     overhead
```

A model that barely fits serves almost nobody: there is no room left for KV cache. Rule of thumb: the weights should take at most about half to two thirds of the memory you give the model.

## Mixture of experts (MoE)

Many recent open models (DeepSeek, Qwen MoE, Kimi) are **MoE**: only a fraction of the parameters work on each token, which makes them fast. But **all** parameters must still be in memory. Size them by total parameters, not active ones.

## Try it

- Open the [model memory estimator](https://huggingface.co/docs/accelerate/usage_guides/model_size_estimator) ("Gradio Demos" section), paste a model name from Hugging Face and compare `float16` against `int4`.
- With the table above: does a 32B model in FP16 fit on one 80 GB GPU with room for users? And in FP8?

## Check yourself

<details><summary>1. How much memory do the weights of a 14B model take in BF16?</summary>
14 × 2 = about 28 GB.
</details>
<details><summary>2. A 70B model in FP8 is 70 GB. Is one 80 GB GPU enough to serve it?</summary>
It loads, but only about 10 GB would be left for KV cache and overhead, so very few requests fit. You want two GPUs or a smaller model.
</details>
<details><summary>3. An MoE model has 30B parameters but only 3B active per token. How much memory for the weights in BF16?</summary>
About 60 GB: all 30B parameters must be loaded, even if only 3B work per token.
</details>

## Read more (10 min)

- [Hugging Face: model memory estimator](https://huggingface.co/docs/accelerate/usage_guides/model_size_estimator): read "Caveats with this calculator".
- [Databricks: LLM inference performance engineering](https://www.databricks.com/blog/llm-inference-performance-engineering-best-practices): "How does quantization reduce LLM inference hardware requirements?".
