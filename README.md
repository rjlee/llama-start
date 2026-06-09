# llama-server

Docker compose configurations for running LLM inference servers on NVIDIA GPUs using [llama.cpp](https://github.com/ggml-org/llama.cpp) and [ik_llama.cpp](https://github.com/ikawrakow/ik-llama-cpp).

## Prerequisites

- NVIDIA GPU with Docker and [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- Model files downloaded to `/models/` on the host

## Usage

List available models:

```bash
./llama-start
```

Start a model:

```bash
./llama-start unsloth-qwen3.6-35b-a3b-ik
```

Disable the slot-cleaner sidecar:

```bash
./llama-start --no-slot-cleaner unsloth-qwen3.6-27b
```

Run benchmarks across all models:

```bash
bash benchmark/benchmark.sh
```

## Models

| Compose name | Model | GGUF | Engine | Context | TG |
|---|---|---|---|---|---|
| `unsloth-qwen3.6-35b-a3b-ik` | Qwen3.6-35B-A3B | APEX I-Compact | ik_llama | 192K | 143 |
| `unsloth-qwen3.6-35b-a3b-mtp` | Qwen3.6-35B-A3B | UD-Q4_K_M MTP | llama.cpp | 128K | 79 |
| `unsloth-qwen3.6-35b-a3b` | Qwen3.6-35B-A3B | UD-Q4_K_M | llama.cpp | 128K | 46 |
| `unsloth-qwen3.6-27b-mtp` | Qwen3.6-27B | Q4_K_M MTP | ik_llama | 200K | 47 |
| `unsloth-qwen3.6-27b` | Qwen3.6-27B | Q4_K_M | ik_llama | 128K | 31 |
| `unsloth-qwen3.5-9b-mtp` | Qwen3.5-9B | UD-Q4_K_XL MTP | ik_llama | 256K | 106 |
| `unsloth-qwen3.5-9b` | Qwen3.5-9B | UD-Q4_K_XL | ik_llama | 256K | 105 |
| `jackrong-qwopus3-5-9b-coder-mtp` | Qwopus3.5-9B-Coder | Q4_K_M MTP | ik_llama | 256K | 102 |
| `jackrong-qwopus3-5-9b-coder` | Qwopus3.5-9B-Coder | Q4_K_M | ik_llama | 256K | 120 |

TG = tokens/second (256-token completion, server mode).

## Files

| File | Purpose |
|------|---------|
| `llama-start` | Model launcher with model listing, health checks, and slot-cleaner |
| `slot-cleaner.sh` | Sidecar to clean stale inference slots (enabled by default) |
| `compose.*.yml` | Docker compose files per model and engine variant |
| `benchmark/benchmark.sh` | Automated benchmark runner (llama-bench + server completion) |
| `benchmark/results/*.json` | Benchmark results (completion and llama-bench) |

## Engine Notes

- [ik_llama.cpp](https://github.com/ikawrakow/ik-llama-cpp) provides ~12-30% faster decode than mainline llama.cpp on the same GPU
- Some larger GGUFs (22 GB+) require mainline llama.cpp due to VRAM constraints on 24 GB cards
- Persistence mode (`nvidia-smi -pm 1`) is enabled automatically to maximise available VRAM
- The slot-cleaner sidecar is started automatically with each model and polls `/slots/:id_slot/erase` every 30 seconds
