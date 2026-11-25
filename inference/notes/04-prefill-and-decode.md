# Prefill and decode

**In one line:** prefill processes the whole prompt in parallel and produces the first token; decode then generates the rest one token per step.

## The idea

Every request goes through two phases that behave very differently on the GPU:

```
request ─▶ [ PREFILL: all prompt tokens at once ] ─▶ token 1 ─▶ [ decode ] ─▶ token 2 ─▶ [ decode ] ─▶ … ─▶ end
            heavy maths, one pass                    TTFT       one small step per token
```

- **Prefill** reads all prompt tokens in parallel. It is a lot of maths in one go, so it is limited by the GPU's **compute**. It also fills the KV cache (note 11) with the prompt.
- **Decode** produces one token per step. Each step does little maths but must read **all the weights** from GPU memory again. It is limited by **memory bandwidth**, and the GPU's compute sits mostly idle.

## The two numbers users feel

- **Time to first token (TTFT):** waiting in the queue + prefill. A long prompt (an agent with 50k tokens of context) means a longer wait before anything appears.
- **Inter-token latency (ITL):** the time of one decode step. It sets the streaming speed. At 50 tokens per second, a 500-token answer takes 10 s, however fast the prefill was.

## Why this shapes the platform

- Decode leaves compute idle, so the server **batches the decode steps of many users** together: one read of the weights serves all of them (note 13).
- Long prefills can stall everyone else's streaming. vLLM's **chunked prefill** splits a long prompt into pieces and mixes them with other users' decode steps.
- Agents are prefill-heavy (huge prompts, short answers); chat is decode-heavy. The same GPU behaves differently for each.

## Try it

Stream a long answer and time the first token against the rest:

```bash
time curl -sN https://litellm.resiz.es/v1/chat/completions -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"<model>","stream":true,"messages":[{"role":"user","content":"Write 300 words about DNS"}]}' > /dev/null
```

Run it again with a long prompt (paste a big file into the message): the total grows mostly before the first token.

## Check yourself

<details><summary>1. Why is decode limited by memory bandwidth and not by compute?</summary>
Each step makes only one token per request, so there is little maths, but all the weights must be read from memory every step.
</details>
<details><summary>2. An agent complains it takes 8 s to start answering, then streams fast. Which phase?</summary>
Prefill (and possibly queueing): high TTFT, normal ITL. Usually a very long prompt.
</details>
<details><summary>3. What does chunked prefill protect?</summary>
The streaming speed of other users, by not letting one long prompt monopolise the GPU.
</details>

## Read more (15 min)

- [Databricks: LLM inference performance engineering](https://www.databricks.com/blog/llm-inference-performance-engineering-best-practices): "Why is memory bandwidth the main bottleneck for LLM inference speed?".
- [vLLM optimization and tuning](https://docs.vllm.ai/en/latest/configuration/optimization.html): "Chunked Prefill".
