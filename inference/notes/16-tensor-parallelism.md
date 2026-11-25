# Tensor parallelism

**In one line:** one model split across several GPUs that work on every token together, used when the model does not fit in one GPU or to get more KV cache.

- **Tensor parallelism** splits each layer across the GPUs of one instance. In vLLM: `--tensor-parallel-size 4`. It needs the fast link inside the instance.
- **Pipeline parallelism** puts different layers on different GPUs or instances. It works across instances but adds waiting between stages.
- The memory freed by splitting the weights goes to KV cache, so more requests fit.
- Usual choice: tensor parallelism inside one instance; pipeline only when a model needs more than one instance.
- Try it: a 70B model in FP16 needs about 140 GB. How many 80 GB H100s, as a power of two, leave room for KV cache?

Source: [vLLM optimization and tuning](https://docs.vllm.ai/en/latest/configuration/optimization.html)
