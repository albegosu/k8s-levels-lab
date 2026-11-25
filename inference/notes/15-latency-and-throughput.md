# Latency and throughput

**In one line:** a user feels latency, the platform pays for throughput, and a bigger batch trades one for the other.

- **Time to first token (TTFT):** from the request to the first token. Driven by prefill and by the queue. `vllm:time_to_first_token_seconds`.
- **Inter-token latency (ITL):** time between tokens while streaming. Driven by decode and by batch size. `vllm:inter_token_latency_seconds`.
- **Throughput:** tokens per second for the whole server, across all requests.
- More requests in the batch raise throughput but make each one a bit slower. Set limits from what users accept, for example TTFT under 2 s for an agent.
- Try it: in Grafana or `/metrics`, look at the p50 and p95 of TTFT, not the average.

Source: [vLLM metrics](https://docs.vllm.ai/en/latest/design/metrics.html)
