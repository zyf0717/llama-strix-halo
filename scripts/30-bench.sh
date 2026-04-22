#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
default_model_dir="${repo_root}/models"
default_model="${default_model_dir}/gpt-oss-120b-MXFP4-00001-of-00002.gguf"
default_llama_bench_bin="${repo_root}/third_party/llama.cpp/build-vulkan/bin/llama-bench"
default_results_dir="${repo_root}/results"

cd "${repo_root}"

if [[ -f .env ]]; then
	set -a
	# shellcheck disable=SC1091
	source .env
	set +a
fi

export GGML_LOG_LEVEL="${GGML_LOG_LEVEL:-2}"
export GGML_VK_VISIBLE_DEVICES="${GGML_VK_VISIBLE_DEVICES:-0}"
export AMD_VULKAN_ICD="${AMD_VULKAN_ICD:-RADV}"

model_dir="${MODEL_DIR:-${default_model_dir}}"
model="${MODEL:-${model_dir}/gpt-oss-120b-MXFP4-00001-of-00002.gguf}"
llama_bench_bin="${LLAMA_BENCH_BIN:-${default_llama_bench_bin}}"
results_dir="${RESULTS_DIR:-${default_results_dir}}"
ngl="${LLAMA_BENCH_NGL:-999}"
threads="${LLAMA_BENCH_THREADS:-8}"
prompt_gen="${LLAMA_BENCH_PG:-256,128}"
batch_size="${LLAMA_BENCH_BATCH:-2048}"
ubatch_size="${LLAMA_BENCH_UBATCH:-1024}"
flash_attention="${LLAMA_BENCH_FA:-1}"
timestamp="$(date +%Y%m%d_%H%M%S)"
log_file="${results_dir}/${timestamp}.log"

if [[ ! -x "${llama_bench_bin}" ]]; then
	echo "llama-bench binary not found or not executable: ${llama_bench_bin}" >&2
	exit 1
fi

if [[ ! -e "${model}" ]]; then
	echo "model not found: ${model}" >&2
	exit 1
fi

mkdir -p "${results_dir}"

command=(
	"${llama_bench_bin}"
	-m "${model}"
	-ngl "${ngl}"
	-t "${threads}"
	-pg "${prompt_gen}"
	-b "${batch_size}"
	-ub "${ubatch_size}"
	-fa "${flash_attention}"
	-mmp 0
	"$@"
)

"${command[@]}" 2>&1 | tee "${log_file}"

exit "${PIPESTATUS[0]}"