# Asking the right questions, and answering them

**In one line:** a customer's question is rarely answerable as asked; your job is to turn it into one with numbers (workload, targets, constraints), answer with assumptions and a range, and say how you will confirm it.

## Why this is a skill

"How many GPUs do I need?" has no answer until you know for which model, how many users doing what, how fast, how reliable, and at what price. Experienced people do not know more answers; they ask the questions that make the answer computable, and they notice which question the customer did not ask but should have.

## The discovery checklist

Before sizing or diagnosing anything, get these. Mark each as **known**, **assumed** (and write the assumption) or **unknown**.

| Area | Questions | Why it matters (equation, note 18) |
| --- | --- | --- |
| **Users and use** | Who uses it: chat, coding agent, RAG, batch? How many people, how many at peak? Growth in 6 months? | Little's law (5); agents and RAG mean long contexts |
| **Request shape** | Prompt and answer length, p50 and p95? Shared system prompt or documents? Streaming? | KV (2), prefill (4), prefix caching |
| **Targets** | Acceptable wait for the first token? Streaming speed? Error budget? Must it survive a node failure? | They turn "fast" into a pass/fail test |
| **Model** | Which model and why? Is a smaller or quantized one acceptable? Is there an eval to prove it? Context actually needed? | Memory (1), speed (3), quality |
| **Constraints** | Cloud and region? Data residency? Existing GPUs, quota, reservations? Budget? | What is possible before what is optimal |
| **Operations** | Several teams sharing it? Per-team limits and budgets? Who is on call? Fallback to an external API allowed? | Gateway design, alerting (note 23) |

## Vague to measurable

| The customer asks | The question that can be answered | What answers it |
| --- | --- | --- |
| "Is H100 enough?" | Does model X, at precision P, serve N requests in flight of length L within TTFT/ITL targets, with one replica down? | Notes 19–21, then a benchmark |
| "How many users can we have?" | How many requests in flight at peak, at what lengths and targets, and what is our in-flight / users ratio? | Note 20 |
| "Why is it slow?" | Which metric (TTFT or ITL), which percentile, for whom, since when? | Note 25 |
| "Should we buy B300?" | What is the cost per concurrent slot that meets targets, can we fill it, and can we get it? | Note 27 |
| "Can we use the 405B model?" | What does it do better on *our* tasks than a 70B or an MoE, and is that worth 5× the hardware? | An eval, then notes 19–20 |
| "Can we raise the context to 128k?" | How many requests really need it, and what does it cost everyone else? | Note 18, worked example |
| "Why do we get 429s (or 422s)?" | Which key, which limit or budget, and is the limit right for the use? | Gateway metrics, note 22 |

## Questions customers forget to ask

- **Quality after quantization.** FP8 is usually safe, FP4 depends on the checkpoint. Who checks, with which eval?
- **Real context lengths.** "128k context" in the model card does not mean you can serve many 128k requests.
- **Availability.** One replica is one failure away from an outage, and the cold start is minutes (note 24).
- **Capacity and quota.** The best GPU on paper may not be available in their region this quarter.
- **Utilisation and cost.** A node idle at night costs the same; at low traffic an external API can be cheaper.
- **Who owns the client.** Agents that send 90k-token prompts or retry aggressively are a client design problem, not a GPU problem.

## Answering: the three-part answer

Every answer to a customer has three parts:

1. **Assumptions:** the numbers you used, especially the ones you assumed.
2. **The answer as a range,** with the main risk.
3. **How we will confirm it,** and when.

> "Assuming 200 developers, about 50 requests in flight at peak with prompts up to 32k, and TTFT under 3 s: Qwen3 235B in FP8 fits on one 8 × H200 node as two replicas, with roughly 2–3× headroom. The main risk is prompt length: if your agents send 64k prompts, capacity halves. We will run a benchmark with a sample of your real prompts this week and confirm the number before you reserve capacity."

Compare with "yes, one H200 node is enough": the second answer is the one that comes back to bite you.

### Saying "it depends" in a useful way

"It depends" is only an answer if you say **on what** and **how much**: *"It depends mostly on prompt length: at 8k you get about 25 requests per replica, at 32k about 6."* Give the curve, not the excuse.

### Saying "I don't know yet"

*"I don't know yet; it depends on X. I'll measure it by Thursday."* is a good answer. A confident guess that turns out wrong costs more trust than the delay.

## Try it: role-play

With a colleague, or by writing both sides:

1. The customer says: *"We want our own model instead of OpenAI. What do we need?"* Ask questions until every row of the checklist is known or assumed. Count how many questions it took.
2. Write the three-part answer, using `fit.py` for the numbers.
3. Swap roles: the customer now answers "we don't know" to half the questions. Write the assumptions you would propose instead.

## Check yourself

<details><summary>1. A customer asks "how many GPUs for Llama 70B?". What are the first three questions?</summary>
How many requests in flight at peak (users and use), how long are prompts and answers, and what latency and availability targets. Precision and GPU type follow.
</details>
<details><summary>2. What is wrong with answering "about 25 users" for 2 × H100?</summary>
25 is requests in flight at 8k tokens, not users, and it ignores the targets and availability. State the assumptions and convert with the in-flight ratio.
</details>
<details><summary>3. The customer insists on a single number. What do you give?</summary>
The number under explicitly stated assumptions, plus the one assumption that changes it most, and the date you will have a measured number.
</details>

## Read more (15 min)

- [Databricks: LLM inference performance engineering](https://www.databricks.com/blog/llm-inference-performance-engineering-best-practices): read it as a model of how to explain latency, throughput and cost trade-offs with numbers.
- [Google SRE book: Service level objectives](https://sre.google/sre-book/service-level-objectives/): "Choosing Targets". How to agree targets that mean something.
