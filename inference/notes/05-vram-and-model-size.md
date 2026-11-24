# VRAM and model size

**In one line:** the weights must fit in GPU memory, and their size is parameters × bytes per parameter.

- In 16-bit precision (FP16/BF16) each parameter takes 2 bytes: an 8B model needs about 16 GB, a 70B model about 140 GB, just for the weights.
- The rest of the GPU memory goes to the KV cache (phase 2), which decides how many requests fit at once. A model that barely fits serves almost nobody.
- Rule of thumb: weights should take at most about half to two thirds of the GPU memory you give the model.
- A model too big for one GPU is split across several (tensor parallelism), which adds cost and network between GPUs.

Source: [vLLM docs](https://docs.vllm.ai/en/latest/)
