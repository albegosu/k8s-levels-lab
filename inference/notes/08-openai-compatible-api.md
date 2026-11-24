# The OpenAI-compatible API

**In one line:** almost every server and gateway speaks the same HTTP API, so harnesses can switch models by changing a base URL and a key.

- `POST /v1/chat/completions` (messages in, message out) is the common one. Codex uses the newer `/v1/responses`; LiteLLM serves both.
- `stream: true` sends tokens as they are generated (server-sent events), which is why agents feel responsive.
- Tool calling (function calling) travels in this same API. A model or server without good tool-calling support makes a poor coding agent, however smart it is.
- Try it: `curl $BASE/v1/chat/completions -H "Authorization: Bearer $KEY" -d '{"model":"<name>","messages":[{"role":"user","content":"hi"}]}'`

Sources: [vLLM OpenAI-compatible server](https://docs.vllm.ai/en/latest/serving/openai_compatible_server.html), [LiteLLM virtual keys](https://docs.litellm.ai/docs/proxy/virtual_keys)
