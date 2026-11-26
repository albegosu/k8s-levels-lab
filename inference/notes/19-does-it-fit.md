# Does model X fit on GPU Y?

**In one line:** a model fits when its weights, plus room for the KV cache of at least the users you need, fit in the memory of the GPUs of **one node**; memory is decided by the **total** parameters, even in MoE models.

## The four inputs

| Input | Where to find it | Trap |
| --- | --- | --- |
| **Total parameters** | Model card, or the size of the `safetensors` files | MoE models: memory needs **all** experts, not the active ones. Qwen3 235B-A22B needs 235B worth of memory, not 22B |
| **Precision of the weights** | Model card, `config.json` → `quantization_config` | BF16 = 2 bytes, FP8 = 1, FP4 = 0.5 per parameter (note 06) |
| **Usable GPU memory** | GPU × count × `--gpu-memory-utilization` (0.9) | Minus a few GB per GPU for activations and CUDA graphs |
| **KV cache per request** | `config.json`: layers, KV heads, head size (note 11) | Grows with context length; it decides how many users fit (note 20) |

```
fits  ⟺  weights  +  KV cache of the requests you need  ≤  GPUs × memory × 0.9  −  reserve
```

"It loads" is not "it fits": a model that loads with 2 GB left serves one short request at a time.

## The GPUs you will be asked about

| GPU | Generation | Memory | Bandwidth | Native low precision | Interconnect |
| --- | --- | --- | --- | --- | --- |
| L4 | Ada | 24 GB | 0.3 TB/s | FP8 | PCIe only |
| L40S | Ada | 48 GB | 0.86 TB/s | FP8 | PCIe only |
| A100 | Ampere | 80 GB | 2.0 TB/s | none (INT8) | NVLink |
| H100 SXM | Hopper | 80 GB | 3.35 TB/s | FP8 | NVLink |
| H200 | Hopper | 141 GB | 4.8 TB/s | FP8 | NVLink |
| B200 | Blackwell | 180 GB | 8 TB/s | FP8, FP4 | NVLink 5 |
| B300 | Blackwell Ultra | 288 GB | 8 TB/s | FP8, FP4 | NVLink 5 |

Figures from NVIDIA spec sheets; HGX/DGX systems put 8 per node. AWS lists GPU memory in GiB, so a p6-b300 shows 2,144 GiB: that is 8 × 288 GB.

What changes from Hopper to Blackwell, for serving:

- **Memory per GPU** goes from 80 to 180–288 GB. A 70B model in FP8 needs 2 H100s but fits on one B200 with room to spare; a 235B MoE needs 4 H100s but fits on 2 B300s.
- **Bandwidth** goes from 3.35 to 8 TB/s: about 2.4× faster decode per GPU (note 09).
- **Native FP4** (NVFP4, MXFP4): half the memory of FP8 and faster tensor cores. On Hopper you can still *load* FP4 weights (gpt-oss ships in MXFP4), but they run through slower kernels.

## Worked example: Llama 3.3 70B in FP8, 8k tokens per request

Output of `python3 inference/tools/fit.py --model llama-3.1-70b` (fewest GPUs in one node that fit):

| GPU | GPUs | Weights | KV room | Requests that fit |
| --- | --- | --- | --- | --- |
| L4 | 4 | 71 GB | 8 GB | 2, and tensor parallelism over PCIe |
| L40S | 2 | 71 GB | 12 GB | 4, over PCIe |
| H100 | 2 | 71 GB | 69 GB | 25 |
| H200 | 1 | 71 GB | 54 GB | 20 |
| B200 | 1 | 71 GB | 89 GB | 33 |
| B300 | 1 | 71 GB | 187 GB | 69 |

Three lessons:

1. **"Fits" is a range, not a yes/no.** The L40S pair "fits" and serves 4 users.
2. **One big GPU beats two small ones** when it fits: no tensor-parallel traffic (note 16), and one failure domain less.
3. **PCIe-only GPUs (L4, L40S) are for models that fit in one of them.** Splitting across them works, but every token pays the PCIe trip.

## Very large models: when one node is not enough

DeepSeek V3/R1 (671B, FP8) needs about 671 GB of weights. 8 H100s give 576 GB usable: **it does not fit in one H100 node**. It fits in 8 H200s, 8 B200s or 4 B300s. On H100 it needs two nodes (pipeline parallelism, or llm-d style wide expert parallelism), which is a different class of problem: cross-node networking (EFA/InfiniBand) becomes part of the serving path.

## Try it

```bash
python3 inference/tools/fit.py --list
python3 inference/tools/fit.py --model qwen3-235b-a22b              # every GPU
python3 inference/tools/fit.py --model qwen3-235b-a22b --weights fp4  # Blackwell only, natively
python3 inference/tools/fit.py --model gpt-oss-120b --weights fp4 --gpu h100
```

Then add a model you care about: copy its `num_hidden_layers`, `num_key_value_heads`, `head_dim` and parameter count from `config.json` into `MODELS` in the script.

## Check yourself

<details><summary>1. A customer says "the model is 30B-A3B, so it needs 3 GB in FP8". What is wrong?</summary>
3B is the active parameters per token. Memory needs all 30B: about 30 GB in FP8, plus KV cache.
</details>
<details><summary>2. Llama 70B FP8: 2 × H100 or 1 × H200?</summary>
2 × H100 gives slightly more KV room (69 against 54 GB) and twice the bandwidth, but needs tensor parallelism. 1 × H200 is simpler and is one failure domain. For a few users, the H200; for the most users per node, compare whole nodes (note 27).
</details>
<details><summary>3. Why can DeepSeek V3 not run on a single p5 (8 × H100)?</summary>
Its FP8 weights (~671 GB) exceed the ~576 GB usable in 8 × 80 GB at 90 %, before any KV cache.
</details>

## Read more (15 min)

- [vLLM: GPU memory and parallelism](https://docs.vllm.ai/en/latest/configuration/optimization.html): "Parallelism Strategies" and "Memory".
- [NVIDIA HGX platform](https://www.nvidia.com/en-us/data-center/hgx/): the per-node memory of Hopper, Blackwell and Blackwell Ultra.
