# Context window

**In one line:** the maximum number of tokens, prompt plus output, that a model can handle in one request.

## The idea

A model is trained to handle sequences up to a certain length: 8k, 32k, 128k tokens or more. That is its **context window**. Everything the model knows about your request must fit inside it: system prompt, tools, `AGENTS.md`, open files, the whole conversation and the answer it is about to write.

```
context window (e.g. 128k tokens)
┌────────────┬──────┬───────────────┬────────────────────────────┬──────────────┐
│ system     │tools │ AGENTS.md     │ conversation + tool results │ room for the │
│ prompt     │      │ + open files  │ (grows every turn)          │ answer       │
└────────────┴──────┴───────────────┴────────────────────────────┴──────────────┘
```

## Bigger is not free

- **Memory:** every token in the context holds KV cache (note 11). A server that allows 128k tokens per request fits far fewer requests than one that allows 32k.
- **Time:** a longer prompt means a longer prefill and a later first token (note 04).
- **Quality:** models use the start and the end of a long context better than the middle ("lost in the middle"). Information buried in a huge prompt is easier to miss.

## In the platform

- The server can cap the window below what the model supports: `--max-model-len 32768` in vLLM. It is a capacity decision: shorter windows, more users per GPU.
- In vLLM, requests over the limit are rejected with an error, not silently cut. Not every server does this: Ollama truncates the prompt to its context size (`num_ctx`) without failing, so the model silently loses the start of the conversation.
- Harnesses **compact** when they approach the limit: they drop or summarise older messages. Quality usually drops before the hard limit, which is why agents "forget" instructions in long sessions.

## Try it

Ask the gateway what it says about a model:

```bash
curl -s $BASE_URL/v1/model/info -H "Authorization: Bearer $KEY" \
  | jq '.data[] | {model: .model_name, max_input: .model_info.max_input_tokens, max_output: .model_info.max_output_tokens}'
```

Then, in your harness, look for the indicator of how much of the context is used, and watch it grow over a session.

## Check yourself

<details><summary>1. Why might a platform serve a 128k-token model with a 32k limit?</summary>
Each request then needs at most a quarter of the KV cache, so about four times as many requests fit on the same GPUs.
</details>
<details><summary>2. An agent ignores a rule from `AGENTS.md` late in a long session. Why?</summary>
The context is very long and the rule sits in the middle, or the harness has already compacted it. Start a new session or repeat the rule.
</details>
<details><summary>3. Does the answer count against the context window?</summary>
Yes: prompt tokens plus completion tokens must fit.
</details>

## Read more (10 min)

- [Lost in the Middle: How Language Models Use Long Contexts](https://arxiv.org/abs/2307.03172): read the abstract and look at the first figure.
- [vLLM engine arguments](https://docs.vllm.ai/en/latest/configuration/engine_args.html): in "ModelConfig", find `--max-model-len`.
