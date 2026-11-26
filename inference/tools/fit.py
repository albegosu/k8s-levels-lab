#!/usr/bin/env python3
"""Does model X fit on GPU Y, and how many requests can it serve at once?

A back-of-the-envelope estimator for notes 19-21 and 27. It tells you what to
benchmark, not what to promise: always confirm with a real benchmark (note 21).

  python3 inference/tools/fit.py --list
  python3 inference/tools/fit.py --model llama-3.1-70b --gpu all
  python3 inference/tools/fit.py --model qwen3-235b-a22b --gpu h100 --count 8 --ctx 32768
  python3 inference/tools/fit.py --model qwen3-235b-a22b --gpu b300 --count 2 --weights fp8 --kv fp8

Model figures come from each model's config.json on Hugging Face; GPU figures
from NVIDIA spec sheets (memory in GB = 10^9 bytes). Standard library only.
"""

import argparse
import math
import sys

# Memory in GB (10^9 bytes), bandwidth in TB/s, and which low-precision formats
# the tensor cores run natively. AWS lists p6-b300 memory in GiB (2,144 GiB for
# 8 GPUs = 268 GiB = 288 GB each).
GPUS = {
    "l4":       {"name": "L4",         "mem": 24,  "bw": 0.30, "fp8": True,  "fp4": False, "nvlink": False},
    "a10g":     {"name": "A10G",       "mem": 24,  "bw": 0.60, "fp8": False, "fp4": False, "nvlink": False},
    "l40s":     {"name": "L40S",       "mem": 48,  "bw": 0.86, "fp8": True,  "fp4": False, "nvlink": False},
    "a100":     {"name": "A100 80GB",  "mem": 80,  "bw": 2.0,  "fp8": False, "fp4": False},
    "h100":     {"name": "H100 SXM",   "mem": 80,  "bw": 3.35, "fp8": True,  "fp4": False},
    "h200":     {"name": "H200",       "mem": 141, "bw": 4.8,  "fp8": True,  "fp4": False},
    "b200":     {"name": "B200",       "mem": 180, "bw": 8.0,  "fp8": True,  "fp4": True},
    "b300":     {"name": "B300",       "mem": 288, "bw": 8.0,  "fp8": True,  "fp4": True},
}

# Parameters in billions. For MoE models: `dense` is always read every step
# (attention, embeddings, shared experts); `experts` is the total of all routed
# experts, of which `top_k` of `n_experts` are used per token.
# KV cache: standard attention stores K and V per layer and KV head;
# MLA (DeepSeek) stores one compressed latent per layer; sliding-window layers
# only keep the last `window` tokens.
MODELS = {
    "llama-3.1-8b": {
        "name": "Llama 3.1 8B", "dense": 8.0,
        "layers": 32, "kv_heads": 8, "head_dim": 128,
    },
    "qwen3-32b": {
        "name": "Qwen3 32B", "dense": 32.8,
        "layers": 64, "kv_heads": 8, "head_dim": 128,
    },
    "llama-3.1-70b": {
        "name": "Llama 3.1 / 3.3 70B", "dense": 70.6,
        "layers": 80, "kv_heads": 8, "head_dim": 128,
    },
    "llama-3.1-405b": {
        "name": "Llama 3.1 405B", "dense": 405.0,
        "layers": 126, "kv_heads": 8, "head_dim": 128,
    },
    "gpt-oss-120b": {
        "name": "gpt-oss-120b (MoE, 5.1B active)", "dense": 1.5,
        "experts": 115.5, "n_experts": 128, "top_k": 4,
        "layers": 36, "kv_heads": 8, "head_dim": 64,
        "sliding_layers": 18, "window": 128,
    },
    "qwen3-235b-a22b": {
        "name": "Qwen3 235B-A22B (MoE, 22B active)", "dense": 7.8,
        "experts": 227.2, "n_experts": 128, "top_k": 8,
        "layers": 94, "kv_heads": 4, "head_dim": 128,
    },
    "deepseek-v3": {
        "name": "DeepSeek V3 / R1 (MoE + MLA, 37B active)", "dense": 16.5,
        "experts": 654.5, "n_experts": 256, "top_k": 8,
        "layers": 61, "mla_dim": 576,
    },
}

BYTES = {"bf16": 2.0, "fp8": 1.0, "fp4": 0.5}
GB = 1e9


def total_params(m):
    return m["dense"] + m.get("experts", 0.0)


def active_params(m):
    if "experts" not in m:
        return m["dense"]
    return m["dense"] + m["experts"] * m["top_k"] / m["n_experts"]


def weight_bytes(m, wprec):
    return total_params(m) * 1e9 * BYTES[wprec]


def kv_bytes_per_request(m, ctx, kvprec):
    """KV cache bytes for one request holding `ctx` tokens."""
    b = BYTES[kvprec]
    if "mla_dim" in m:
        return m["layers"] * m["mla_dim"] * b * ctx
    per_layer_token = 2 * m["kv_heads"] * m["head_dim"] * b
    sliding = m.get("sliding_layers", 0)
    full = m["layers"] - sliding
    return per_layer_token * (full * ctx + sliding * min(ctx, m.get("window", ctx)))


def weights_read_per_step(m, wprec, batch):
    """Bytes of weights read in one decode step with `batch` requests.

    Dense models read all weights once per step. MoE models read the dense part
    plus every expert touched by at least one request in the batch; with uniform
    routing the touched fraction is 1 - (1 - k/E)^batch, so it tends to all of
    them as the batch grows.
    """
    if "experts" not in m:
        return m["dense"] * 1e9 * BYTES[wprec]
    touched = 1 - (1 - m["top_k"] / m["n_experts"]) ** batch
    return (m["dense"] + m["experts"] * touched) * 1e9 * BYTES[wprec]


def estimate(m, g, count, wprec, kvprec, ctx, util, reserve_gb, mbu, overhead_ms):
    usable = g["mem"] * GB * util * count
    reserve = reserve_gb * GB * count
    w = weight_bytes(m, wprec)
    kv_room = usable - reserve - w
    per_req = kv_bytes_per_request(m, ctx, kvprec)
    max_reqs = max(0, int(kv_room // per_req)) if kv_room > 0 else 0
    bw = g["bw"] * 1e12 * count * mbu

    def step(batch):
        read = weights_read_per_step(m, wprec, batch) + batch * per_req
        return read / bw + overhead_ms / 1000

    return {
        "usable": usable, "weights": w, "kv_room": kv_room,
        "per_req": per_req, "max_reqs": max_reqs, "step": step,
    }


def fmt_gb(x):
    return f"{x / GB:,.0f} GB"


def warn_precision(g, wprec, kvprec, count=1):
    notes = []
    if count > 1 and not g.get("nvlink", True):
        notes.append(f"{g['name']} has no NVLink: tensor parallelism over PCIe makes every token slower than estimated.")
    for label, p in (("weights", wprec), ("KV cache", kvprec)):
        if p == "fp8" and not g["fp8"]:
            notes.append(f"{g['name']} has no native FP8: {label} in FP8 save memory but run through slower kernels.")
        if p == "fp4" and not g["fp4"]:
            notes.append(f"{g['name']} has no native FP4 (Blackwell only): {label} in FP4 save memory, no speed-up.")
    return notes


def print_detail(m, g, count, a):
    e = estimate(m, g, count, a.weights, a.kv, a.ctx, a.util, a.reserve, a.mbu, a.overhead)
    print(f"{m['name']} on {count} x {g['name']}  (weights {a.weights}, KV {a.kv}, {a.ctx:,} tokens per request)")
    print()
    print(f"  usable memory   {fmt_gb(e['usable'])}  ({count} x {g['mem']} GB x {a.util})")
    print(f"  weights         {fmt_gb(e['weights'])}  ({total_params(m):,.0f}B params, {active_params(m):,.1f}B active per token)")
    print(f"  reserved        {fmt_gb(a.reserve * GB * count)}  (activations, CUDA graphs: {a.reserve} GB per GPU)")
    if e["kv_room"] <= 0:
        print(f"  KV cache room   none: DOES NOT FIT. Add GPUs, use a lower precision or a bigger GPU.")
        return
    print(f"  KV cache room   {fmt_gb(e['kv_room'])}")
    print(f"  KV per request  {e['per_req'] / 2**20:,.0f} MiB at {a.ctx:,} tokens")
    print(f"  memory limit    {e['max_reqs']} requests at once at this context length")
    for n in warn_precision(g, a.weights, a.kv, count):
        print(f"  note            {n}")
    if e["max_reqs"] == 0:
        return
    print()
    print(f"  Decode speed (memory-bound estimate: {int(a.mbu * 100)} % of peak bandwidth + {a.overhead:g} ms per step, every request at {a.ctx:,} tokens):")
    print(f"  {'requests':>9}  {'ITL':>8}  {'tok/s per user':>14}  {'tok/s total':>11}")
    batches = sorted({1, 4, 16, 64, 256, e["max_reqs"]})
    best = 0
    for b in batches:
        if b > e["max_reqs"]:
            continue
        s = e["step"](b)
        if s * 1000 <= a.itl_slo:
            best = max(best, b)
        print(f"  {b:>9}  {s * 1000:>6.1f}ms  {1 / s:>14.0f}  {b / s:>11,.0f}")
    # search the exact largest batch that meets the ITL target
    lo, hi = 0, e["max_reqs"]
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if e["step"](mid) * 1000 <= a.itl_slo:
            lo = mid
        else:
            hi = mid - 1
    print()
    print(f"  memory limit:  {e['max_reqs']} requests")
    print(f"  speed limit:   {lo} requests keep ITL under {a.itl_slo:.0f} ms")
    print(f"  => plan for about {min(lo, e['max_reqs'])} concurrent requests per replica, then benchmark it (note 21).")


def print_matrix(m, a):
    print(f"{m['name']}: smallest setup per GPU (weights {a.weights}, KV {a.kv}, {a.ctx:,} tokens per request, ITL < {a.itl_slo:.0f} ms)")
    print()
    print(f"  {'GPU':<10} {'GPUs':>4}  {'weights':>8}  {'KV room':>8}  {'mem limit':>9}  {'ITL limit':>9}  note")
    for key, g in GPUS.items():
        row = None
        for count in (1, 2, 4, 8):
            e = estimate(m, g, count, a.weights, a.kv, a.ctx, a.util, a.reserve, a.mbu, a.overhead)
            if e["max_reqs"] >= 1:
                lo, hi = 0, e["max_reqs"]
                while lo < hi:
                    mid = (lo + hi + 1) // 2
                    if e["step"](mid) * 1000 <= a.itl_slo:
                        lo = mid
                    else:
                        hi = mid - 1
                row = (count, e, lo)
                break
        if row is None:
            print(f"  {g['name']:<10} {'-':>4}  {fmt_gb(weight_bytes(m, a.weights)):>8}  {'':>8}  {'':>9}  {'':>9}  does not fit in 8 GPUs")
            continue
        count, e, lo = row
        short = []
        for p_, label in ((a.weights, "weights"), (a.kv, "KV")):
            if (p_ == "fp8" and not g["fp8"]) or (p_ == "fp4" and not g["fp4"]):
                short.append(f"no native {p_.upper()} {label}")
        if count > 1 and not g.get("nvlink", True):
            short.append("TP over PCIe")
        note = ", ".join(short)
        print(f"  {g['name']:<10} {count:>4}  {fmt_gb(e['weights']):>8}  {fmt_gb(e['kv_room']):>8}  {e['max_reqs']:>9}  {lo:>9}  {note}")
    print()
    print("  GPUs: fewest of 1, 2, 4 or 8 in one node that fit with room for one request.")
    print("  mem limit: requests whose KV cache fits. ITL limit: requests before decode gets slower than the target.")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--model", help="model key (see --list)")
    p.add_argument("--gpu", default="all", help="GPU key, or 'all' for a comparison table")
    p.add_argument("--count", type=int, default=1, help="GPUs in one node, tensor parallel (default 1)")
    p.add_argument("--weights", choices=BYTES, default="fp8", help="weight precision (default fp8)")
    p.add_argument("--kv", choices=BYTES, default="bf16", help="KV cache precision (default bf16)")
    p.add_argument("--ctx", type=int, default=8192, help="tokens per request: prompt + answer (default 8192)")
    p.add_argument("--util", type=float, default=0.9, help="vLLM --gpu-memory-utilization (default 0.9)")
    p.add_argument("--reserve", type=float, default=2.0, help="GB per GPU for activations and CUDA graphs (default 2)")
    p.add_argument("--mbu", type=float, default=0.7, help="fraction of peak bandwidth reached in decode (default 0.7)")
    p.add_argument("--overhead", type=float, default=5.0, help="fixed ms per decode step: kernel launches, scheduling, TP traffic (default 5)")
    p.add_argument("--itl-slo", type=float, default=50.0, help="inter-token latency target in ms (default 50)")
    p.add_argument("--list", action="store_true", help="list models and GPUs")
    a = p.parse_args()

    if a.list or not a.model:
        print("Models:")
        for k, m in MODELS.items():
            print(f"  {k:<18} {m['name']}")
        print("GPUs:")
        for k, g in GPUS.items():
            print(f"  {k:<18} {g['name']:<10} {g['mem']:>4} GB  {g['bw']:.2f} TB/s")
        return 0 if a.list else 1
    if a.model not in MODELS:
        sys.exit(f"unknown model {a.model!r}; see --list")
    m = MODELS[a.model]
    if a.gpu == "all":
        print_matrix(m, a)
        return 0
    if a.gpu not in GPUS:
        sys.exit(f"unknown GPU {a.gpu!r}; see --list")
    print_detail(m, GPUS[a.gpu], a.count, a)
    return 0


if __name__ == "__main__":
    sys.exit(main())
