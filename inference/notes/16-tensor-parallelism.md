# Tensor parallelism

**In one line:** one model split across several GPUs that work on every token together, used when the model does not fit in one GPU or to get more room for KV cache.

## The options

| Strategy | What is split | Where it works | vLLM flag |
| --- | --- | --- | --- |
| **Tensor parallelism (TP)** | Each layer, across GPUs | GPUs in one instance, with a fast link | `--tensor-parallel-size` |
| **Pipeline parallelism (PP)** | Groups of layers, one group per GPU or node | Across instances | `--pipeline-parallel-size` |
| **Data parallelism (DP)** | Nothing: full copies of the model | Anywhere | Several replicas |
| **Expert parallelism (EP)** | The experts of an MoE model | Large MoE models | `--enable-expert-parallel` |

```
TP=4: every layer is cut in 4, all GPUs work on every token and talk after each layer
┌ GPU0 ┐ ┌ GPU1 ┐ ┌ GPU2 ┐ ┌ GPU3 ┐
│ ¼ L1 │↔│ ¼ L1 │↔│ ¼ L1 │↔│ ¼ L1 │   ← needs NVLink-class speed inside the instance
│ ¼ L2 │↔│ ¼ L2 │↔│ ¼ L2 │↔│ ¼ L2 │
└──────┘ └──────┘ └──────┘ └──────┘
```

## How to choose

- **The model fits in one GPU with room for users:** no splitting. Scale out with replicas (DP).
- **It does not fit, or leaves no room for KV cache:** TP inside one instance, usually 2, 4 or 8 GPUs (powers of two that divide the model's attention heads).
- **It does not fit in one instance:** TP inside each instance + PP across instances. Rare outside very large models.

Splitting the weights also frees memory on each GPU, which becomes KV cache, so TP can raise capacity even when the model would fit.

## The cost

The GPUs exchange data after every layer, for every token. Inside an instance with a fast link that costs little; across a normal network it would make every token slow. That is why TP stays inside one instance.

## Try it

A 70B model in BF16 is about 140 GB. On H100s (80 GB each), compare TP=2 and TP=4: how much memory per GPU is left for KV cache in each case, using 90 % of each GPU? Which one would you choose for an agent platform with long contexts?

## Check yourself

<details><summary>1. Why not use TP across two separate instances?</summary>
Every layer of every token would wait for the network between instances, which is far slower than the link inside one.
</details>
<details><summary>2. A model fits in one GPU. When would you still use TP=2?</summary>
When the leftover memory for KV cache is too small for the users or context lengths you need.
</details>
<details><summary>3. TP or more replicas to serve more users of a small model?</summary>
More replicas (data parallelism): no communication between GPUs and simpler to scale.
</details>

## Read more (15 min)

- [vLLM optimization and tuning](https://docs.vllm.ai/en/latest/configuration/optimization.html): read "Parallelism Strategies", including TP, PP, EP and DP.
- [Hugging Face TGI: tensor parallelism](https://huggingface.co/docs/text-generation-inference/conceptual/tensor_parallelism): a short page with a diagram.
