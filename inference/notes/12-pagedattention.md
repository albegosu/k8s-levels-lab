# PagedAttention

**In one line:** vLLM stores the KV cache in small fixed-size blocks, like pages of virtual memory, instead of one big reserved chunk per request.

- Before it, servers reserved memory for the maximum length of every request up front, and most of it was never used.
- With blocks, a request only takes the memory it actually uses, and the blocks do not need to be contiguous. The vLLM authors reported almost no wasted KV memory, so many more requests fit in the same GPU.
- Blocks can be shared between requests, which is what makes prefix caching (note 14) cheap.
- This idea is a large part of why vLLM serves more requests per GPU than older servers.
- Try it: read the first sections of the vLLM launch post and find the figures for memory waste before and after.

Source: [vLLM: Easy, Fast, and Cheap LLM Serving with PagedAttention](https://vllm.ai/blog/2023-06-20-vllm)
