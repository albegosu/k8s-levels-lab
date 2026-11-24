# What "serving a model" means

**In one line:** a model server loads the weights into GPU memory once and then answers requests by generating text one token at a time.

- Training changes the weights; inference only reads them. Everything in this path is about inference.
- A model server (vLLM, llama.cpp, TGI) owns the GPU, batches requests together and exposes an HTTP API. A gateway (LiteLLM) sits in front: keys, budgets, routing, logs.
- Cost has two parts: keeping the weights loaded (a GPU that is busy or not) and doing the work per request (tokens).
- Try it: `curl http://<server>/v1/models` lists what a server has loaded.

Source: [vLLM docs](https://docs.vllm.ai/en/latest/)
