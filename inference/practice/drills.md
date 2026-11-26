# Estimation drills

Sixteen quick questions to do on paper, in two minutes each, with the equations of note 18. The goal is to get the order of magnitude right without a tool, so you can sanity-check any number a customer, a vendor or a dashboard gives you. Check with `fit.py` afterwards where it applies.

Use: BF16 = 2 bytes, FP8 = 1, FP4 = 0.5 · H100 80 GB, 3.35 TB/s, ~1 PFLOPS BF16 · L4 24 GB, 0.3 TB/s · usable memory = 90 %.

## Memory

<details><summary>1. A 24B dense model in BF16 and in FP8: weights?</summary>
48 GB and 24 GB.
</details>

<details><summary>2. 48 layers, 8 KV heads, head size 128, BF16 cache: KV per token?</summary>
2 × 48 × 8 × 128 × 2 = 196,608 bytes = 192 KiB.
</details>

<details><summary>3. 100 GB free for cache, 128 KiB per token: how many 32k requests? And with an FP8 cache?</summary>
One request = 32,768 × 128 KiB = 4 GiB ≈ 4.3 GB, so about 23. With FP8, about 46.
</details>

<details><summary>4. Llama 70B FP8 on 2 × H100, ~69 GB of cache room: how many 16k requests?</summary>
16,384 × 320 KiB = 5 GiB ≈ 5.4 GB per request: about 12.
</details>

<details><summary>5. A "30B-A3B" MoE in FP8: memory for weights?</summary>
About 30 GB: memory counts all experts. The "3B" only matters for speed.
</details>

## Speed

<details><summary>6. 8B model in FP8 on one L4: upper bound of tokens/s for one user?</summary>
0.3 TB/s ÷ 8 GB ≈ 37 tokens/s. Real: lower.
</details>

<details><summary>7. The same on one H100?</summary>
3,350 ÷ 8 ≈ 420 tokens/s as a bound; in practice the fixed per-step overhead (a few ms) dominates and you see far less. Small models on big GPUs are overhead-bound, not bandwidth-bound.
</details>

<details><summary>8. Prefill of a 20k-token prompt, 8B model in BF16, one H100 at 50 % efficiency?</summary>
2 × 8·10⁹ × 2·10⁴ = 3.2·10¹⁴ FLOP ÷ (10¹⁵ × 0.5) ≈ 0.65 s.
</details>

<details><summary>9. Qwen3 235B-A22B in FP8 (128 experts, 8 active): weights read per step at batch 1 and at batch 64?</summary>
Batch 1: about the active 22 GB. Batch 64: the fraction of experts touched is 1 − (1 − 8/128)⁶⁴ ≈ 98 %, so nearly all 235 GB. MoE decode is cheap for few users and close to dense for many.
</details>

<details><summary>10. Llama 70B FP8 on 2 × H100 (6.7 TB/s, 70 % reached), 5 ms overhead, ITL target 50 ms, 8k requests (2.7 GB of KV each): how many requests before ITL passes the target? Which ceiling binds first?</summary>
Weights: 70 GB ÷ 4.7 TB/s ≈ 15 ms, plus 5 ms = 20 ms. 30 ms left × 4.7 TB/s ≈ 141 GB of KV ≈ 52 requests. Memory fits only ~25 (drill 4 style), so the memory ceiling binds first.
</details>

## Load and capacity

<details><summary>11. 3 requests/s at peak, 12 s per request: requests in flight?</summary>
36.
</details>

<details><summary>12. 400 chat users, about 8 % in flight at peak: requests in flight?</summary>
32.
</details>

<details><summary>13. A replica holds 40 within targets. Peak 120 in flight, you plan at 65 % utilisation, and must survive losing one replica. How many replicas?</summary>
120 ÷ (40 × 0.65) ≈ 4.6, so 5; with one down, 4 × 40 = 160 still covers 120 at 75 %. 5 replicas.
</details>

<details><summary>14. Qwen3 235B on one 8 × H100 node: one TP=8 replica or two TP=4? (32k requests, FP8 cache)</summary>
TP=8: ~103 requests. Two TP=4: 2 × 14 = 28, because each keeps its own 235 GB copy of the weights. One TP=8 has far more capacity; two replicas only buy availability, at a large cost. Better: two nodes, or a bigger-memory GPU.
</details>

## Cost

<details><summary>15. Node at 50 $/h producing 2,000 tokens/s at full load: cost per million tokens? And at 25 % average load?</summary>
50 ÷ (2,000 × 3,600) × 10⁶ ≈ 6.9 $. At 25 %: about 28 $.
</details>

<details><summary>16. Which is cheaper per token: one node at 90 % load, or a node with twice the price and three times the throughput at 40 % load?</summary>
Cost ∝ price ÷ (throughput × load). First: 1 ÷ 0.9 ≈ 1.11. Second: 2 ÷ (3 × 0.4) ≈ 1.67. The first, unless you can fill the bigger one.
</details>
