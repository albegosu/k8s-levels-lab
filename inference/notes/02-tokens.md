# Tokens

**In one line:** models read and write tokens, pieces of text from a fixed vocabulary, not characters or words.

## The idea

A model cannot read letters. Before anything else, a **tokenizer** cuts the text into pieces from a fixed list, the **vocabulary** (tens of thousands to a couple of hundred thousand entries), and replaces each piece with its number. The model only ever sees and produces those numbers.

The vocabulary is built from training text: chunks that appear often become a single token, rare ones are spelled out from smaller pieces. A common English word is usually one token; a rare word, a long variable name or a UUID is split into several. The most common method is **byte pair encoding (BPE)**, which starts from single bytes and keeps merging the most frequent pairs.

```
"Deploy the API"  ──tokenizer──▶  [ 69, 1946, 279, 5446 ]  ──model──▶  [ 389 ] ──▶ " to" …
                                     one ID per token                 one new token per step
```

(The IDs are made up; each model family has its own.)

## Why it matters

- **Everything is counted in tokens:** context window, maximum output, price, rate limits per minute, budget per key. When LiteLLM says a key spent X, it is tokens × price.
- **The same text costs different amounts on different models.** Each model family has its own tokenizer, so one prompt can be 10–30 % more tokens on one model than on another.
- **Spanish, code and JSON cost more than English prose.** Tokenizers are trained mostly on English text, so other languages and symbol-heavy text split into more pieces.
- Rough rule for English: about 4 characters or ¾ of a word per token. Use it for estimates, never for billing.

## Try it

1. Open the [tokenizer playground](https://huggingface.co/spaces/Xenova/the-tokenizer-playground), pick a Llama or Qwen tokenizer and paste the same paragraph in English and in Spanish. Then a JSON object and a stack trace.
2. Ask the gateway and read the count the server actually used:

```bash
curl -s https://inference.resizes.eu/v1/chat/completions -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"<model>","max_tokens":1,"messages":[{"role":"user","content":"Despliega la API en producción"}]}' \
  | jq .usage
```

`prompt_tokens` is higher than the number of words: it includes the chat template the server wraps around your message.

## Check yourself

<details><summary>1. Why can the same prompt cost differently on two models?</summary>
Each model family has its own tokenizer and vocabulary, so the same text splits into a different number of tokens.
</details>
<details><summary>2. Why does a JSON payload use more tokens than a sentence of the same length?</summary>
Braces, quotes, keys and IDs are rare chunks in the vocabulary, so they split into more, smaller tokens.
</details>
<details><summary>3. A user sends 10 words and `prompt_tokens` says 40. Is something wrong?</summary>
No. The server adds the chat template (role markers, system prompt, special tokens) around the message.
</details>

## Read more (10 min)

- [Hugging Face: summary of the tokenizers](https://huggingface.co/docs/transformers/tokenizer_summary): read "Byte pair encoding (BPE)" and "Byte-level BPE".
