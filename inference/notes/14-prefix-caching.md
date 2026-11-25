# Prefix caching

**In one line:** when requests start with the same text, the server reuses the KV cache of that shared start instead of computing it again.

- Coding agents send the same system prompt, tool list and `AGENTS.md` at the start of every turn. With prefix caching, only the new part pays for prefill.
- It saves prefill time, so time to first token drops; it does not speed up decode.
- In vLLM it is automatic: blocks with the same content are shared between requests.
- To get hits, keep the fixed part at the start of the prompt and the changing part at the end.
- What to watch: `vllm:prefix_cache_hits` divided by `vllm:prefix_cache_queries`.

Source: [vLLM automatic prefix caching](https://docs.vllm.ai/en/latest/features/automatic_prefix_caching.html)
