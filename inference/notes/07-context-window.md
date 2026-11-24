# Context window

**In one line:** the maximum number of tokens (prompt plus output) a model can handle in one request.

- Bigger is not free: longer contexts need more KV cache memory per request, so fewer requests fit on the GPU, and prefill takes longer.
- The server can be started with a smaller maximum than the model supports (`--max-model-len` in vLLM) to fit more users.
- Coding agents fill the context fast. When it is full, the harness drops or summarizes older messages, and quality drops before the hard limit.
- What to watch: requests rejected for exceeding the context length, and agents that "forget" earlier instructions in long sessions.

Source: [Hugging Face, generation with LLMs](https://huggingface.co/docs/transformers/llm_tutorial)
