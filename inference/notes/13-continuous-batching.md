# Continuous batching

**In one line:** the server adds new requests to the running batch at every step, instead of waiting for the whole batch to finish.

## Why batch at all

A decode step is limited by reading the weights (notes 04 and 09). Reading them once and producing one token for 32 users costs almost the same as for 1 user. So serving many requests in the same step multiplies throughput almost for free. The question is how to form the batch.

## Static against continuous

```
static batching                         continuous batching
step: 1 2 3 4 5 6 7 8                   step: 1 2 3 4 5 6 7 8
A     ■ ■ ■ ■ ■ ■ ■ ■                   A     ■ ■ ■ ■ ■ ■ ■ ■
B     ■ ■ ■ · · · · ·  idle             B     ■ ■ ■ D D D D D   D joins at step 4
C     ■ ■ ■ ■ ■ · · ·  idle             C     ■ ■ ■ ■ ■ E E E   E joins at step 6
D, E  wait until A finishes
```

- **Static:** the batch starts together and ends with its longest request. Short requests finish and leave their slot empty; new ones wait outside.
- **Continuous** (iteration-level scheduling): at every step, finished requests leave and waiting ones take their place. The GPU stays full.

Anyscale measured up to 23 times more throughput than serving one request at a time, while also lowering median latency.

## The limits

vLLM does continuous batching by default. How big the batch gets depends on:

- **KV cache:** each request in the batch needs its cache (note 11). This is usually the real limit.
- **`--max-num-seqs`:** the maximum number of requests per step.
- **Preemption:** if the cache fills up, vLLM pauses some requests and recomputes them later. Frequent preemption means the GPU is overloaded.

What to watch: `vllm:num_requests_running` (in the batch) against `vllm:num_requests_waiting` (in the queue).

## Try it

Send 10 requests at once and compare the total time with sending them one after another:

```bash
for i in $(seq 10); do
  curl -s $BASE_URL/v1/chat/completions -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" \
    -d '{"model":"<model>","messages":[{"role":"user","content":"Write 100 words about DNS"}]}' > /dev/null &
done; time wait
```

On Ollama, how many requests run together is capped by `OLLAMA_NUM_PARALLEL`, so the gain is smaller than on vLLM.

## Check yourself

<details><summary>1. Why does a batch of 32 cost about the same per step as a batch of 1?</summary>
The step is limited by reading the weights from memory, and that read is shared by everyone in the batch.
</details>
<details><summary>2. What wastes the GPU in static batching?</summary>
Slots of finished requests stay empty until the longest request in the batch ends.
</details>
<details><summary>3. Many requests waiting and KV cache usage near 100 %. What does it mean?</summary>
The cache is the limit: you need more GPU memory, shorter contexts, a quantized cache or more replicas.
</details>

## Read more (15 min)

- [How continuous batching enables 23x throughput (Anyscale)](https://www.anyscale.com/blog/continuous-batching-llm-inference): read "LLM batching explained", "Naive batching / static batching" and "Continuous batching".
- [vLLM optimization and tuning](https://docs.vllm.ai/en/latest/configuration/optimization.html): "Preemption".
