# Prompt tokens vs completion tokens

**In one line:** input (prompt) tokens are read all at once; output (completion) tokens are generated one by one, so they are slower and usually priced higher.

- A coding agent sends huge prompts: system prompt, `AGENTS.md`, open files, tool results, the whole conversation. Input often dominates the token count.
- Output is shorter but each token costs a full step of the model, which is why it is slower per token.
- LiteLLM logs both counts per request and per key: that is where spend per person comes from.
- What to watch: a conversation that keeps growing re-sends everything each turn. Starting a fresh conversation is a cost control, not just a habit.

Source: [Databricks, LLM inference performance engineering](https://www.databricks.com/blog/llm-inference-performance-engineering-best-practices)
