# What "serving a model" means

**In one line:** a model server loads the weights into GPU memory once and then answers requests by generating text one token at a time.

## The idea

A model is a big file of numbers, the **weights**: billions of them, learned during training. **Training** changes those numbers and takes weeks on thousands of GPUs. **Inference** only reads them to produce an answer. Everything in this path is about inference.

To answer, the model does not write a whole reply at once. It predicts **the next token** (a piece of a word, note 02), appends it to the text and predicts again, one step at a time, until it decides to stop. A 500-token answer is 500 steps through the whole model. That loop is why responses stream in, and why output is slow and expensive compared with reading the input.

**Serving** means running that loop for many people at once, reliably. A model server:

1. loads the weights into GPU memory when it starts. This takes minutes, so it happens once, not per request;
2. receives requests over HTTP;
3. groups the requests of many users into one batch on the GPU (phase 2), which is how one GPU serves many people;
4. streams the tokens back as they are generated.

## Where each piece sits

```
harness (OpenCode, Codex)
   │  HTTP, OpenAI-compatible API (note 08)
   ▼
gateway: LiteLLM ── keys, budgets, rate limits, routing, logs, spend
   │
   ▼
model server: vLLM ── owns the GPU, batches requests, generates tokens
   │
   ▼
GPU memory: weights + KV cache (notes 05 and 11)
```

- **Model server** (vLLM, also TGI or llama.cpp): one process per model, pinned to its GPUs. It knows nothing about users or money.
- **Gateway** (LiteLLM): the only thing clients talk to. It decides who may call which model and records what each key spends. Harnesses and agents go through the gateway, never straight to vLLM.

## Where the cost comes from

- **Fixed:** a GPU holding the weights costs the same per hour whether it serves one request or a hundred. An idle GPU is pure cost.
- **Variable:** each request consumes GPU time in proportion to its tokens, input and output.
- So the business of serving is **keeping GPUs busy**: enough users per GPU to pay for it, without making each user wait. Most of phases 2 and 3 are tools for that balance.

## Try it

With the URL of an OpenAI-compatible gateway and a key for it (`export BASE_URL=... KEY=...`):

```bash
# What models does the gateway offer?
curl -s $BASE_URL/v1/models -H "Authorization: Bearer $KEY" | jq '.data[].id'

# Watch tokens arrive one by one: each "data:" line is one step of the loop
curl -sN $BASE_URL/v1/chat/completions -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"<model>","stream":true,"messages":[{"role":"user","content":"Count from 1 to 20"}]}'
```

## Check yourself

<details><summary>1. Why does the server load the weights at startup and not per request?</summary>
Loading tens of GB into GPU memory takes minutes. Per request, every answer would take minutes.
</details>
<details><summary>2. A 1,000-token prompt produces a 200-token answer. How many generation steps?</summary>
About 200 for the output. The prompt is read in one parallel pass (prefill, note 04), not token by token.
</details>
<details><summary>3. Why put LiteLLM in front instead of exposing vLLM?</summary>
vLLM has no notion of users, budgets or several models behind one URL. The gateway adds keys, limits, routing and spend per person.
</details>

## Read more (15 min)

- [Databricks: LLM inference performance engineering](https://www.databricks.com/blog/llm-inference-performance-engineering-best-practices): read the first two sections, "How do large language models generate text?" and "What metrics matter for measuring LLM serving performance?". The best short explanation of the generation loop and why it costs what it costs.
- [vLLM quickstart](https://docs.vllm.ai/en/latest/getting_started/quickstart.html): skim "Online Serving" to see how little it takes to start a server.
