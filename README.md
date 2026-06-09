# llama-start

Docker compose configurations for running LLM inference servers on NVIDIA GPUs using [llama.cpp](https://github.com/ggml-org/llama.cpp), [ik_llama.cpp](https://github.com/ikawrakow/ik-llama-cpp), and [beellama.cpp](https://github.com/Anbeeld/beellama.cpp).

## Prerequisites

- NVIDIA GPU with Docker and [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- Model files — set `MODELS_DIR` (default: `/models`) or download to `/models/`

## Usage

List available models:

```bash
./llama-start
```

Start a model:

```bash
./llama-start ik_llama-unsloth-qwen3.6-35b-a3b
```

Disable the slot-cleaner sidecar:

```bash
./llama-start --no-slot-cleaner ik_llama-unsloth-qwen3.6-27b
```

Run benchmarks across all models:

```bash
./benchmark/benchmark
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| `MODELS_DIR` | `/models` | Host path to the directory containing model GGUF files |

Set these in your shell environment or add them to the project's `.env` file.

## Models

| Compose name | Model | GGUF | Engine | Context | TG |
|---|---|---|---|---|---|
| `ik_llama-unsloth-qwen3.6-35b-a3b` | Qwen3.6-35B-A3B | APEX I-Compact | ik_llama | 192K | 143 |
| `llama.cpp-unsloth-qwen3.6-35b-a3b-mtp` | Qwen3.6-35B-A3B | UD-Q4_K_M MTP | llama.cpp | 128K | 79 |
| `llama.cpp-unsloth-qwen3.6-35b-a3b` | Qwen3.6-35B-A3B | UD-Q4_K_M | llama.cpp | 128K | 46 |
| `beellama-unsloth-qwen3.6-27b` | Qwen3.6-27B | Q4_K_M DFlash | beellama | 131K | 80 |
| `ik_llama-unsloth-qwen3.6-27b-mtp` | Qwen3.6-27B | Q4_K_M MTP | ik_llama | 200K | 47 |
| `ik_llama-unsloth-qwen3.6-27b` | Qwen3.6-27B | Q4_K_M | ik_llama | 128K | 31 |
| `ik_llama-jackrong-qwopus3.5-9b-coder` | Qwopus3.5-9B-Coder | Q4_K_M | ik_llama | 256K | 120 |
| `ik_llama-unsloth-qwen3.5-9b-mtp` | Qwen3.5-9B | UD-Q4_K_XL MTP | ik_llama | 256K | 106 |
| `ik_llama-unsloth-qwen3.5-9b` | Qwen3.5-9B | UD-Q4_K_XL | ik_llama | 256K | 105 |
| `ik_llama-jackrong-qwopus3.5-9b-coder-mtp` | Qwopus3.5-9B-Coder | Q4_K_M MTP | ik_llama | 256K | 102 |

TG = tokens/second (256-token completion, server mode).

## Files

| File | Purpose |
|------|---------|
| `llama-start` | Model launcher with model listing, health checks, and slot-cleaner |
| `compose/*.yml` | Docker compose files per model and engine variant |
| `slot-cleaner/slot-cleaner.sh` | Sidecar to clean stale inference slots (enabled by default) |
| `slot-cleaner/compose.slot-cleaner.yml` | Docker compose fragment for the slot-cleaner sidecar |
| `benchmark/benchmark` | Automated benchmark runner (llama-bench + server completion) |
| `benchmark/results/*.json` | Benchmark results (completion and llama-bench) |

## Engine Notes

- [ik_llama.cpp](https://github.com/ikawrakow/ik-llama-cpp) provides ~12-30% faster decode than mainline llama.cpp on the same GPU. Best engine for the 35B APEX GGUF.
- [beellama.cpp](https://github.com/Anbeeld/beellama.cpp) is a performance fork adding DFlash speculative decoding and TurboQuant KV compression. Uses a lightweight draft GGUF alongside the target model for 1.7-2.6x speedup on compatible models (requires a separate DFlash draft GGUF).
- Some larger GGUFs (22 GB+) require mainline llama.cpp due to VRAM constraints on 24 GB cards
- Persistence mode (`nvidia-smi -pm 1`) is enabled automatically to maximise available VRAM
- The slot-cleaner sidecar is started automatically with each model. It polls `/slots/:id_slot/erase` every 30 seconds to clean up stale inference slots left behind after client disconnects or request timeouts — preventing slots from filling up and blocking new requests.
- Override the models directory by setting `MODELS_DIR` in your environment (e.g. `export MODELS_DIR=/data/models`)

---

*Model compose configurations were adapted from [club-3090](https://github.com/noonghunna/club-3090).*
