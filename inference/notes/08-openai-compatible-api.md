# The OpenAI-compatible API

**In one line:** almost every model server and gateway speaks the same HTTP API, so a harness switches models by changing a base URL, a key and a model name.

## The idea

OpenAI's API became the common language. vLLM, LiteLLM, Ollama and most providers copy it, so the same client code works against any of them. That is what makes the harness and the model independent (the agentic-coding talk, point 1).

### Request and response

```http
POST /v1/chat/completions
Authorization: Bearer <key>

{ "model": "<name>",
  "messages": [ {"role": "system", "content": "You are…"},
                {"role": "user",   "content": "Fix the failing test"} ],
  "tools": [ { "type": "function", "function": { "name": "read_file", "parameters": {…} } } ],
  "stream": true }
```

The answer is either text, or a **tool call**: the model asks the harness to run `read_file` with some arguments. The harness runs it, adds the result as a new message and calls the API again. That loop is the whole agent.

### The pieces worth knowing

- **`/v1/chat/completions`:** messages in, message out. The one almost everything uses.
- **`/v1/responses`:** OpenAI's newer API. Codex only speaks this one; LiteLLM serves it in front of any model.
- **`stream: true`:** tokens arrive as server-sent events (`data: …` lines) while they are generated.
- **`usage`:** prompt and completion tokens of the request (note 03).
- **Tool calling:** the server must turn the model's output into structured tool calls. In vLLM this needs `--enable-auto-tool-choice` and the right `--tool-call-parser` for the model family. Without it, a smart model makes a useless coding agent.

## Try it

Ask for a tool call and look at the shape of the answer:

```bash
curl -s $BASE_URL/v1/chat/completions -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" -d '{
  "model":"<model>",
  "messages":[{"role":"user","content":"What is the weather in Madrid?"}],
  "tools":[{"type":"function","function":{"name":"get_weather","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}]
}' | jq '.choices[0].message'
```

A good setup returns `tool_calls` with `{"city":"Madrid"}`, not a text answer.

## Check yourself

<details><summary>1. What does a harness change to move from one provider to a self-hosted gateway?</summary>
The base URL, the API key and the model name. The request format stays the same.
</details>
<details><summary>2. The model answers well in chat but the agent never edits files. What do you check first?</summary>
Tool calling on the server: whether the response contains `tool_calls`, and the tool-call parser configured in vLLM.
</details>
<details><summary>3. Why does Codex need LiteLLM in front of vLLM?</summary>
Codex only speaks the Responses API; LiteLLM serves it and translates for the model behind.
</details>

## Read more (15 min)

- [vLLM tool calling](https://docs.vllm.ai/en/latest/features/tool_calling.html): read "Quickstart" and "Automatic Function Calling".
- [vLLM OpenAI-compatible server](https://docs.vllm.ai/en/latest/serving/openai_compatible_server.html): skim the list of supported APIs.
