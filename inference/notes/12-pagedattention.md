# PagedAttention

**In one line:** vLLM stores the KV cache in small fixed-size blocks, like pages of virtual memory, instead of one big reserved chunk per request.

## The problem it solved

Before vLLM, servers reserved one contiguous chunk of memory per request, sized for the **maximum** length it might reach. A request that might write 2,000 tokens but stopped at 200 left 90 % of its chunk empty, and nobody else could use it. The vLLM authors measured that existing systems wasted most of their KV cache memory this way.

## The idea

Borrowed from how operating systems manage RAM:

```
request A:  [blk 3] → [blk 7] → [blk 1]          each block = a few tokens (16 by default)
request B:  [blk 5] → [blk 2]                    blocks anywhere in GPU memory
free:       [blk 0] [blk 4] [blk 6] [blk 8] …    taken only when a request needs one more
```

- The cache is split into small **blocks** of a few tokens each.
- A request gets a new block only when it fills the last one, so it wastes at most part of one block.
- Blocks need not be next to each other: a block table maps each request to its blocks.
- Blocks can be **shared**: if two requests start with the same text, they point at the same blocks. This is what makes prefix caching (note 14) and generating several answers from one prompt cheap.

## Why it matters

With almost no waste, many more requests fit in the same GPU, so batches are bigger (note 13) and throughput goes up. It is a large part of why vLLM outperformed earlier servers, and the idea is now standard (TGI, SGLang and others use it too).

## Try it

Read the first two sections of the vLLM launch post (below) and write down the memory waste figures it gives for earlier systems and for vLLM. Then explain to yourself how the analogy with OS memory pages maps onto requests and tokens.

## Check yourself

<details><summary>1. Why did reserving for the maximum length waste memory?</summary>
Most requests stop well before the maximum, and the reserved space could not be lent to other requests.
</details>
<details><summary>2. What is the most a request wastes with PagedAttention?</summary>
The unused part of its last block: at most a few tokens' worth.
</details>
<details><summary>3. How does PagedAttention make prefix caching possible?</summary>
Blocks can be shared, so requests with the same beginning point at the same cached blocks.
</details>

## Read more (15 min)

- [vLLM: Easy, Fast, and Cheap LLM Serving with PagedAttention](https://vllm.ai/blog/2023-06-20-vllm): read "The Secret Sauce: PagedAttention".
- [Hugging Face TGI: PagedAttention](https://huggingface.co/docs/text-generation-inference/conceptual/paged_attention): a short second explanation.
- For depth: the [PagedAttention paper](https://arxiv.org/abs/2309.06180), sections 1–3.
