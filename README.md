# llama-strix-halo

Lightweight workspace for benchmarking and serving LLMs via `llama.cpp` (ggml).

## Repo layout

```text
llama-strix-halo/
├─ README.md
├─ .env            # local (ignored) – copy from .env.example
├─ .env.example
├─ config/
│  └─ servers/    # first-class server instance env files
├─ scripts/        # helper scripts for fetch/build/bench/serve
├─ prompts/
├─ models/         # tracked symlinks only (do NOT add large GGUF files here)
├─ results/        # benchmark output by default
├─ logs/           # server output by default
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

3. Build `llama.cpp` according to its README or use the provided helpers. For HIP/ROCm builds, install ROCm once with `scripts/01-install-rocm-ubuntu.sh`, reboot or log out/in, then run `scripts/21-build-hip.sh`. For Vulkan/RADV builds, run `scripts/20-build-vulkan.sh`. The built binaries appear under `third_party/llama.cpp/build-*/bin/` (e.g. `llama-bench`, `llama-server`).

4. Add or link your GGUF model shards under `models/` (see Models section).

5. Run benchmarks or serve server instances:

    - Benchmark: `./scripts/30-bench.sh` (creates `results/YYYYMMDD_HHMMSS.log` and `results/YYYYMMDD_HHMMSS.env.txt` by default; override with `RESULTS_DIR` if you want to move benchmark output)
    - Restart both servers: `./scripts/40-restart-servers.sh`
    - Restart primary only: `./scripts/40-restart-servers.sh primary` or `./scripts/41-restart-primary-server.sh`
    - Restart secondary only: `./scripts/40-restart-servers.sh secondary` or `./scripts/42-restart-secondary-server.sh`

## Scripts

- `scripts/00-capture-env.sh` — captures run metadata, git state, runtime vars, and available system/GPU/Vulkan details into the active output directory as `<timestamp>.env.txt`.
- `scripts/01-install-rocm-ubuntu.sh` — configures AMD ROCm apt repositories on Ubuntu and installs the HIP build packages. Set `INSTALL_FULL_ROCM=1` only when you want the full `rocm` meta-package.
- `scripts/10-fetch-llamacpp.sh` — add/init `third_party/llama.cpp` submodule. Use `LLAMACPP_REF` in `.env` to pin a specific commit.
- `scripts/20-build-vulkan.sh`, `scripts/21-build-hip.sh` — platform build helpers.
- `scripts/30-bench.sh` — runs `llama-bench`. Logs to `results/<timestamp>.log`. Configurable via `.env`:
   - `GGML_LOG_LEVEL`, `GGML_VK_VISIBLE_DEVICES`, `AMD_VULKAN_ICD`
   - `MODEL_DIR`, `MODEL`, `LLAMA_BENCH_BIN`, `RESULTS_DIR`
- `scripts/40-restart-servers.sh` — restarts both servers by default, or one configured `llama-server` instance when passed a server ID.
- `scripts/41-restart-primary-server.sh` — primary wrapper for `./scripts/40-restart-servers.sh primary`.
- `scripts/42-restart-secondary-server.sh` — secondary wrapper for `./scripts/40-restart-servers.sh secondary`.

## Server instances

- `config/servers/primary.env` and `config/servers/secondary.env` are first-class peer configs. They are ignored by Git because they are local machine config.
- Tracked examples live at `config/servers/primary.env.example` and `config/servers/secondary.env.example`; copy them to `config/servers/primary.env` and `config/servers/secondary.env` before launching on a fresh checkout.
- Restarting one server only stops an existing `llama-server` process for the same binary and port, so `primary` and `secondary` can run concurrently.

## Models

- The `models/` directory should contain only symlinks to your GGUF shard files (these files are large and should live outside the repo). Example:

   ln -s /absolute/path/to/gpt-oss-120b-MXFP4-00001-of-00002.gguf models/gpt-oss-120b-MXFP4-00001-of-00002.gguf
   ln -s /absolute/path/to/gpt-oss-120b-MXFP4-00002-of-00002.gguf models/gpt-oss-120b-MXFP4-00002-of-00002.gguf

- Make the symlink visible to Git by adding a negation to `models/.gitignore`, for example:

   echo "!gpt-oss-120b-MXFP4-00001-of-00002.gguf" >> models/.gitignore

   Then `git add models/gpt-oss-120b-MXFP4-00001-of-00002.gguf models/.gitignore` and commit.

- Alternatively, set `MODEL_DIR` in your `.env` to point to a shared model directory on your machine (preferred for portability).

## Qwen3-4B model

- Download the lightweight GGUF into your shared model directory:

   huggingface-cli download unsloth/Qwen3-4B-Instruct-2507-GGUF Qwen3-4B-Instruct-2507-UD-Q4_K_XL.gguf --local-dir ~/models/Qwen3-4B-Instruct-2507-GGUF

- Link it into the repo model directory:

   ln -s ~/models/Qwen3-4B-Instruct-2507-GGUF/Qwen3-4B-Instruct-2507-UD-Q4_K_XL.gguf models/Qwen3-4B-Instruct-2507-UD-Q4_K_XL.gguf

- Start the secondary server instance:

   ./scripts/40-restart-servers.sh secondary

- The secondary server listens on `0.0.0.0:1235` with one `16K` slot by default. The primary server listens on `0.0.0.0:1234`.

## `.env` format

- The helper scripts read `.env` as simple `KEY=VALUE` data, not as a shell script.
- Supported lines are blank lines, `#` comments, and `KEY=VALUE` assignments with optional single or double quotes. Unquoted inline comments are supported when `#` is preceded by whitespace.
- `.env` is for machine-global settings such as `LLAMACPP_REF`, backend/device choices, shared paths, and benchmark defaults.
- Server-specific settings live in ignored `config/servers/<server-id>.env` files created from the tracked `config/servers/<server-id>.env.example` templates.

## Submodule pinning

- The `third_party/llama.cpp` gitlink in the superproject pins the exact commit to use. To update:

   cd third_party/llama.cpp
   git fetch origin
   git checkout <commit-or-tag>
   cd ../..
   git add third_party/llama.cpp
   git commit -m "Update llama.cpp submodule to <commit>"

## Logs

- Benchmark output is written to `results/` by default with filenames in `YYYYMMDD_HHMMSS.log` format.
- Server output is written to each server config's `LLAMA_SERVER_RESULTS_DIR`.
- Each benchmark/server run also writes `<timestamp>.env.txt` alongside the log with the resolved command, model path, git revisions, runtime env, and available system diagnostics.
- Use `tail -f <configured-output-dir>/<latest>.log` to inspect the live run output.
