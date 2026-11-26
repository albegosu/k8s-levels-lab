# A method for "it is slow" and "it fails"

**In one line:** turn the complaint into a metric, find the layer, find the phase, find the ceiling, find what changed, and prove it with one experiment; the same five steps work for every inference ticket.

## Why a method

Inference tickets arrive vague: "the model is slow", "the agent hangs", "it was fine yesterday". The cause can be anywhere between the client app and a GPU. Guessing wastes hours and sometimes money (buying GPUs for a problem that was a rate limit). Level 9 taught a method for Kubernetes; this is the same idea for serving.

## The five steps

```
1. Metric     "slow"           → which number, which percentile, who, since when?
2. Layer      client → gateway → engine → GPU / node
3. Phase      waiting? (TTFT)   streaming? (ITL)   failing? (errors)
4. Ceiling    memory · speed · demand · policy · hardware
5. Change     what changed: deploy, model, traffic mix, client, node?
   → one experiment that confirms it, then the fix, then what to tell the customer
```

### 1. Turn the complaint into a metric

| They say | Ask | You want |
| --- | --- | --- |
| "It is slow" | Slow to start, or slow while writing? Since when? Everyone or one team? | TTFT or ITL p95, a time window, a key or team |
| "It hangs" | Does it end with an error, or never? After how long? | Timeouts in the client vs `finished_reason`, e2e latency |
| "It fails" | Which error code? Every request or some? | 4xx / 5xx split (429 limit, 422 budget in LiteLLM, 5xx backend), by key and by backend |
| "Answers got worse" | Since which date? Which kind of task? | The deploy log: model, quantization, sampling or system prompt changes |

A request ID or timestamp from the customer is worth ten descriptions.

### 2. Find the layer

Compare latency at each hop for the same window:

- **Gateway latency ≫ engine e2e latency:** time lost before the model, in the gateway (its own queue, retries, fallbacks to a slow provider) or the network.
- **Gateway ≈ engine:** the time is spent in the model server; go to step 3.
- **Errors at the gateway, none in the engine:** policy (429 from rate limits, 422 from an exhausted budget in LiteLLM) or routing (wrong model name, backend marked down).
- **Client-side only:** the client's own timeouts, retries or sequential calls. The agent may be making 15 calls per action.

### 3. Find the phase

| What grew | Phase | Points to |
| --- | --- | --- |
| TTFT, with `vllm:request_queue_time_seconds` up | Waiting | Capacity: memory ceiling, or a burst |
| TTFT, queue time flat | Prefill | Longer prompts, prefix cache misses |
| ITL | Decode | Batch too large, very long contexts in the batch, slower GPU |
| Errors / aborts | — | Policy, crashes, hardware |

### 4. Find the ceiling

| Ceiling | Signature in metrics | Typical fix |
| --- | --- | --- |
| **Memory** | KV usage ≈ 1, waiting > 0, preemptions | Scale out, FP8 KV, cap `--max-model-len` |
| **Speed** | ITL high, KV usage well below 1, many running | Cap `--max-num-seqs`, faster GPU, more replicas |
| **Demand** | Few running, nothing waiting, GPU "100 %" | Not a server problem: the client sends one request at a time |
| **Policy** | 429 (rate limit) or 422 (budget) at the gateway, engine idle | Limits or budget of that key/team |
| **Hardware** | Restarts, XID errors, a pod Pending for a GPU | Drain and replace the node; capacity or quota |

### 5. Find what changed

Most incidents follow a change. Check in this order: deploys of the model server or gateway (image, flags, model revision), traffic mix (a new team, a new agent feature with longer contexts), client releases, and infrastructure events (node replaced, Karpenter consolidation, AZ issue).

## When you have no dashboards

vLLM prints a stats line every few seconds; it is enough for steps 3 and 4:

```bash
kubectl logs deploy/<model-server> --since=30m | grep -E 'throughput|KV cache'
# … Avg prompt throughput: 5400.2 tokens/s, Avg generation throughput: 812.5 tokens/s,
#   Running: 48 reqs, Waiting: 7 reqs, GPU KV cache usage: 98.7%, Prefix cache hit rate: 41.0%
```

And for the gateway, the spend logs give prompt and completion tokens per request: that is how you find the 90k-token prompts.

## The answer to the customer

Close every investigation with three sentences: **what happened** (in their words, with the number), **what we did or will do**, and **how we will know it is fixed** (the metric and target). Note 26 covers how to say it.

## Try it

Take the incident table in note 22 and the cases in [practice](../practice/cases.md). For the first three cases, write steps 1–5 before you open the solution.

## Check yourself

<details><summary>1. Gateway p95 is 12 s, vLLM e2e p95 is 4 s. Where do you look?</summary>
At the gateway and in front of it: retries, fallbacks to another provider, its own queue or rate limiting, network. The model server is not where the 8 s go.
</details>
<details><summary>2. TTFT is up, queue time is flat, KV usage is 50 %. Which ceiling?</summary>
None of the capacity ceilings: it is prefill. Look at prompt token sizes and the prefix cache hit rate: prompts got longer or stopped sharing a prefix.
</details>
<details><summary>3. Why ask "what changed" last rather than first?</summary>
Asking it first tempts you to blame the most recent change. Steps 1–4 tell you which layer and phase moved, so you know which change could explain it. In practice you keep it in mind from the start and confirm it at the end.
</details>

## Read more (15 min)

- [Google SRE book: Effective troubleshooting](https://sre.google/sre-book/effective-troubleshooting/): "Theory" and "In Practice". The general method this note adapts.
- [Level 9 of this lab](../../level-9/README.md): the same method on Kubernetes, with faults to find blind.
