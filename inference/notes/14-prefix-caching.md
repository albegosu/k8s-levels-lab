# Prefix caching

**In one line:** when requests start with the same text, the server reuses the KV cache of that shared start instead of computing it again.

## The idea

Remember note 03: a coding agent re-sends the whole conversation every turn, and most of it is identical to the previous turn. Without caching, the server runs prefill over all of it every time.

```
turn 1:  [system prompt | tools | AGENTS.md | msg 1]                        ← prefill all
turn 2:  [system prompt | tools | AGENTS.md | msg 1 | answer 1 | msg 2]     ← only the new tail
          └────────────── already in cache ──────────────┘
```

With prefix caching, the server notices that the beginning of the new request matches blocks it already has (note 12) and only computes the new part.

## What it saves and what it does not

- **Saves prefill:** less GPU work and a much shorter **time to first token** on long contexts.
- **Does not speed up decode:** the answer streams at the same speed.
- **Only exact prefixes count.** One changed character at the start (a timestamp in the system prompt, for example) invalidates everything after it.

In vLLM it is automatic. Rules that make it work:

- Put the fixed parts first (system prompt, tools, project instructions) and the changing parts last.
- Avoid dynamic values at the start of the prompt.

## In the platform

With several replicas of a model behind LiteLLM, a cache only helps if the next turn of a conversation lands **on the same replica**. A random load balancer spreads turns across replicas and loses most hits. That is why prefix-aware routing (phase 3, llm-d) exists.

What to watch: `vllm:prefix_cache_hits` ÷ `vllm:prefix_cache_queries` is the hit rate.

## Try it

Send the same long prompt twice (paste a big file as the message) and time the first token both times. The second should start noticeably sooner on a server with prefix caching.

## Check yourself

<details><summary>1. Why do coding agents benefit so much from prefix caching?</summary>
They re-send a long, mostly identical prompt on every turn.
</details>
<details><summary>2. A system prompt starts with "Current time: 10:42:13". What happens to the cache?</summary>
It changes every request, so nothing after it ever matches. Move it to the end or drop it.
</details>
<details><summary>3. Why can adding replicas lower the hit rate?</summary>
Turns of the same conversation land on different replicas, each with its own cache.
</details>

## Read more (15 min)

- [vLLM automatic prefix caching](https://docs.vllm.ai/en/latest/features/automatic_prefix_caching.html): read "Introduction", "Example workloads" and "Limits".
- [SGLang: RadixAttention](https://lmsys.org/blog/2024-01-17-sglang/): read "Backend: Automatic KV Cache Reuse with RadixAttention" for another design of the same idea.
