# Tokens

**In one line:** models read and write tokens, pieces of words from a fixed vocabulary, not characters or words.

- Rule of thumb in English: about 4 characters or 0.75 words per token. Spanish, code and JSON usually need more tokens for the same text.
- Each model family has its own tokenizer, so the same prompt counts differently on two models.
- Every limit and every price is in tokens: context window, max output, rate limits per minute, budget per key.
- Try it: paste a paragraph in Spanish and the same in English into a tokenizer and compare the counts.

Sources: [Hugging Face tokenizer summary](https://huggingface.co/docs/transformers/tokenizer_summary), [OpenAI tokenizer](https://platform.openai.com/tokenizer)
