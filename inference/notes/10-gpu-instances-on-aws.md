# GPU instances on AWS

**In one line:** each EC2 family pairs one accelerator model with up to 8 of them per instance; choose by memory per accelerator first.

| Family | Accelerator | Memory each | Max per instance | Typical use |
| --- | --- | --- | --- | --- |
| g5 | NVIDIA A10G | 24 GB | 8 | Small models (7–8B), cheap |
| g6 | NVIDIA L4 | 24 GB | 8 | Small models, efficient |
| g6e | NVIDIA L40S | 48 GB | 8 | Mid-size models, or larger ones split over several GPUs |
| p4d / p4de | NVIDIA A100 | 40 / 80 GB | 8 | Large models, previous generation |
| p5 | NVIDIA H100 | 80 GB | 8 | Large models, high throughput |
| p5e / p5en | NVIDIA H200 | about 141 GB | 8 | Very large models |
| inf2 | AWS Inferentia2 | 32 GB | 12 | Lower cost; needs the Neuron SDK instead of CUDA |

- Total memory is memory each × count: a `g6e.48xlarge` has 8 × 48 = 384 GB.
- Inside one instance the GPUs talk over a fast link, so splitting a model across them works well. Across instances it is much slower.
- inf2 is not a drop-in replacement: models must be compiled for Neuron, and not every model or vLLM feature is supported.
- Try it: with the rule from note 05, which family is the smallest that fits an 8B model in FP16? And a 70B model in FP8?

Source: [Amazon EC2 accelerated computing instances](https://aws.amazon.com/ec2/instance-types/accelerated-computing/)
