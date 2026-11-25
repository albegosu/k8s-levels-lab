# Prompt tokens vs completion tokens

**In one line:** input (prompt) tokens are read all at once; output (completion) tokens are generated one by one, so they are slower and usually priced higher, but agents send far more input.

## The idea

Every request has two counts:

- **Prompt tokens:** everything sent to the model. The server reads them in one parallel pass (prefill, note 04).
- **Completion tokens:** what the model writes back. Each one is a full step of the model (note 01).

Per token, output is much more expensive in GPU time, which is why public APIs usually price output several times higher than input. But in a coding agent the **volume** is the other way round.

## Worked example: one agent session

The model remembers nothing between requests (note 01), so the harness re-sends the whole conversation every turn:

| Turn | Prompt tokens | Completion tokens |
| --- | --- | --- |
| 1 | 12,000 (system prompt, tools, `AGENTS.md`, your message) | 400 |
| 2 | 14,000 (all of turn 1 + a tool result) | 400 |
| … | +2,000 per turn | 400 |
| 20 | 50,000 | 400 |
| **Total** | **about 620,000** | **8,000** |

About 99 % of the tokens are input, and most of it is the same text sent again and again. Two consequences:

- **Long sessions get expensive and slow.** Starting a fresh conversation with a short summary is a cost control, not just a habit.
- **Re-sent input is cheap to cache.** Prefix caching (note 14) avoids recomputing the part that did not change.

## In the platform

LiteLLM records both counts for every request and multiplies them by a price per input token and per output token configured for each model. For self-hosted models Resizes sets that price, so spend per key reflects real GPU use.

## Try it

```bash
# Counts for one request
curl -s https://inference.resizes.eu/v1/chat/completions -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"<model>","messages":[{"role":"user","content":"Explain DNS in two lines"}]}' | jq .usage

# What your key has spent so far
curl -s "https://inference.resizes.eu/key/info" -H "Authorization: Bearer $KEY" | jq '.info.spend'
```

## Check yourself

<details><summary>1. Why is an output token more expensive than an input token?</summary>
Input is processed in one parallel pass; each output token needs its own full step through the model.
</details>
<details><summary>2. In the example, what happens to cost if the session goes to 40 turns?</summary>
Input grows roughly with the square of the number of turns: about 2 million prompt tokens instead of 620,000, more than three times as much.
</details>
<details><summary>3. What is the cheapest way to make a long session cheaper?</summary>
Start a new conversation with a short summary, so the re-sent history disappears.
</details>

## Read more (10 min)

- [Databricks: LLM inference performance engineering](https://www.databricks.com/blog/llm-inference-performance-engineering-best-practices): "How do large language models generate text?".
- [LiteLLM: spend tracking](https://docs.litellm.ai/docs/proxy/cost_tracking): "How to Track Spend with LiteLLM".
