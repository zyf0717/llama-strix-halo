# llama-strix-halo

Lightweight workspace for benchmarking and serving LLMs via `llama.cpp` (ggml).

## Repo layout

```text
llama-strix-halo/
├─ README.md
├─ .env            # local (ignored) – copy from .env.example
├─ .env.example
├─ scripts/        # helper scripts for fetch/build/bench/serve
├─ prompts/
├─ models/         # tracked symlinks only (do NOT add large GGUF files here)
├─ results/        # timestamped logs
└─ third_party/
    └─ llama.cpp/   # git submodule (ggml/llama.cpp)
```

## Quickstart

1. Clone and initialize submodules:

    git clone [<repo-url>](https://github.com/zyf0717/llama-strix-halo)
    cd llama-strix-halo
    git submodule update --init --recursive

2. Fetch or initialize `llama.cpp` (script handles submodule add / init and pins by commit):

    ./scripts/10-fetch-llamacpp.sh

3. Build `llama.cpp` according to its README (or use the provided placeholders `scripts/20-build-vulkan.sh` / `scripts/21-build-hip.sh`). The built binaries appear under `third_party/llama.cpp/build-*/bin/` (e.g. `llama-bench`, `llama-server`).

4. Add or link your GGUF model shards under `models/` (see Models section).

5. Run benchmarks or serve models:

    - Benchmark: `./scripts/30-bench.sh` (creates `results/YYYYMMDD_HHMMSS.log` and `results/YYYYMMDD_HHMMSS.env.txt`)
    - Serve model: `./scripts/40-load-model.sh` (starts `llama-server` using `nohup`, logs to `results/` and writes a matching `.env.txt` capture)

## Scripts

- `scripts/00-capture-env.sh` — captures run metadata, git state, runtime vars, and available system/GPU/Vulkan details into `results/<timestamp>.env.txt`.
- `scripts/10-fetch-llamacpp.sh` — add/init `third_party/llama.cpp` submodule. Use `LLAMACPP_REF` in `.env` to pin a specific commit.
- `scripts/20-build-vulkan.sh`, `21-build-hip.sh` (placeholder) — platform build helpers.
- `scripts/30-bench.sh` — runs `llama-bench`. Logs to `results/<timestamp>.log`. Configurable via `.env`:
   - `GGML_LOG_LEVEL`, `GGML_VK_VISIBLE_DEVICES`, `AMD_VULKAN_ICD`
   - `MODEL_DIR`, `MODEL`, `LLAMA_BENCH_BIN`, `RESULTS_DIR`
- `scripts/40-load-model.sh` — starts `llama-server` (backgrounded with `nohup`). Configurable via `.env`:
   - `LLAMA_SERVER_BIN`, `LLAMA_SERVER_NGL`, `LLAMA_SERVER_CTX`, `LLAMA_SERVER_THREADS`, `LLAMA_SERVER_BATCH`, `LLAMA_SERVER_UBATCH`, `LLAMA_SERVER_HOST`, `LLAMA_SERVER_PORT`, `LLAMA_SERVER_ALIAS`, `LLAMA_SERVER_FLASH_ATTN`, `RESULTS_DIR`

## Models

- The `models/` directory should contain only symlinks to your GGUF shard files (these files are large and should live outside the repo). Example:

   ln -s /absolute/path/to/gpt-oss-120b-MXFP4-00001-of-00002.gguf models/gpt-oss-120b-MXFP4-00001-of-00002.gguf
   ln -s /absolute/path/to/gpt-oss-120b-MXFP4-00002-of-00002.gguf models/gpt-oss-120b-MXFP4-00002-of-00002.gguf

- Make the symlink visible to Git by adding a negation to `models/.gitignore`, for example:

   echo "!gpt-oss-120b-MXFP4-00001-of-00002.gguf" >> models/.gitignore

   Then `git add models/gpt-oss-120b-MXFP4-00001-of-00002.gguf models/.gitignore` and commit.

- Alternatively, set `MODEL_DIR` in your `.env` to point to a shared model directory on your machine (preferred for portability).

## `.env` format

- The helper scripts read `.env` as simple `KEY=VALUE` data, not as a shell script.
- Supported lines are blank lines, `#` comments, and `KEY=VALUE` assignments with optional single or double quotes.

## Submodule pinning

- The `third_party/llama.cpp` gitlink in the superproject pins the exact commit to use. To update:

   cd third_party/llama.cpp
   git fetch origin
   git checkout <commit-or-tag>
   cd ../..
   git add third_party/llama.cpp
   git commit -m "Update llama.cpp submodule to <commit>"

## Logs

- Benchmark and server output are written to `results/` with filenames in `YYYYMMDD_HHMMSS.log` format.
- Each benchmark/server run also writes `results/YYYYMMDD_HHMMSS.env.txt` with the resolved command, model path, git revisions, runtime env, and available system diagnostics.
- Use `tail -f results/<latest>.log` to inspect the live run output.