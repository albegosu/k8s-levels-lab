# GPU instances on AWS

**In one line:** each EC2 family pairs one accelerator model with up to 8 of them per instance; choose by memory per accelerator first, then bandwidth and price.

## The families

| Family | Accelerator | Memory each | Max per instance | Typical use |
| --- | --- | --- | --- | --- |
| g5 | NVIDIA A10G | 24 GB | 8 | Small models (7–8B), cheap |
| g6 | NVIDIA L4 | 24 GB | 8 | Small models, efficient, FP8 support |
| g6e | NVIDIA L40S | 48 GB | 8 | Mid-size models, or larger ones split across GPUs |
| p4d / p4de | NVIDIA A100 | 40 / 80 GB | 8 | Large models, previous generation |
| p5 | NVIDIA H100 | 80 GB | 8 | Large models, high throughput |
| p5e / p5en | NVIDIA H200 | about 141 GB | 8 | Very large models |
| inf2 | AWS Inferentia2 | 32 GB | 12 | Lower cost, but needs the Neuron SDK instead of CUDA |

Newer families (p6 with Blackwell GPUs, g7) keep appearing; the method below does not change.

## How to choose

1. **Size the model** (note 05): weights in the precision you will use.
2. **Add room for KV cache** (note 11): the weights should take at most about half to two thirds of the memory.
3. **Pick the smallest GPU, or the fewest GPUs in one instance, where that fits.** Inside one instance the GPUs share a fast link, so splitting a model across them works well (note 16). Across instances it is much slower.
4. **Then compare bandwidth and price** for the speed you need (note 09).

## Things that bite in practice

- **Quotas.** New accounts have zero or very low limits for G and P instances. Request the "Running On-Demand G and VT instances" or "P instances" quota (in vCPUs) days before you need it.
- **Capacity.** Large GPUs are often sold out in a region. For p5 there are Capacity Blocks for ML (reserve GPUs for a fixed period).
- **Spot.** Cheap, but an interrupted GPU drops every request it was serving, and reloading the model takes minutes.
- **inf2 is not a drop-in replacement.** Models must be compiled with Neuron, and not every model or vLLM feature is supported.

## Try it

With note 05's table: which family and how many accelerators would you pick for

1. an 8B model in BF16,
2. a 32B model in FP8,
3. a 70B model in FP8?

Then open the EC2 pricing page for your region and compare the hourly price of your three choices.

## Check yourself

<details><summary>1. Smallest choice for an 8B model in BF16 with room for users?</summary>
One L4 or A10G (24 GB): 16 GB of weights leaves about 6–7 GB for KV cache. Tight; a g6e (48 GB) gives far more users.
</details>
<details><summary>2. Why prefer 4 GPUs in one instance over 4 instances with 1 GPU each for one model?</summary>
Tensor parallelism needs the fast link inside an instance; across instances the network makes every token slower.
</details>
<details><summary>3. The first thing to do before a GPU proof of concept in a new AWS account?</summary>
Request the G or P instance quota: the default is often zero.
</details>

## Read more (10 min)

- [Amazon EC2 accelerated computing instances](https://aws.amazon.com/ec2/instance-types/accelerated-computing/): scan the table for g6e and p5.
- [AWS Neuron documentation](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/): read "Who Neuron is for" before considering inf2.
