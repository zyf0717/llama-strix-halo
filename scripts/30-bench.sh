#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
default_model_dir="${repo_root}/models"
default_model_name="gpt-oss-120b-MXFP4-00001-of-00002.gguf"
default_results_dir="${repo_root}/results"
capture_env_script="${repo_root}/scripts/00-capture-env.sh"

source "${script_dir}/lib/load-env.sh"

cd "${repo_root}"
load_env_file "${repo_root}/.env"

llama_cpp_backend="${LLAMA_CPP_BACKEND:-hip}"

export GGML_LOG_LEVEL="${GGML_LOG_LEVEL:-2}"
export GGML_VK_VISIBLE_DEVICES="${GGML_VK_VISIBLE_DEVICES:-0}"
export AMD_VULKAN_ICD="${AMD_VULKAN_ICD:-RADV}"

model_dir="${MODEL_DIR:-${default_model_dir}}"
model="${MODEL:-${model_dir}/${default_model_name}}"
if [[ -n "${LLAMA_BENCH_BIN:-}" ]]; then
	llama_bench_bin="${LLAMA_BENCH_BIN}"
else
	llama_cpp_build_dir="$(resolve_llama_cpp_build_dir "${repo_root}" "${llama_cpp_backend}")"
	llama_bench_bin="${llama_cpp_build_dir}/bin/llama-bench"
fi
results_dir="${RESULTS_DIR:-${default_results_dir}}"
ngl="${LLAMA_BENCH_NGL:-999}"
threads="${LLAMA_BENCH_THREADS:-8}"
prompt_gen="${LLAMA_BENCH_PG:-256,128}"
batch_size="${LLAMA_BENCH_BATCH:-2048}"
ubatch_size="${LLAMA_BENCH_UBATCH:-1024}"
flash_attention="${LLAMA_BENCH_FA:-1}"
timestamp="$(date +%Y%m%d_%H%M%S)"
log_file="${results_dir}/${timestamp}.log"
capture_file="${results_dir}/${timestamp}.env.txt"

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

printf -v command_str '%q ' "${command[@]}"

RUN_KIND=bench \
RUN_TIMESTAMP="${timestamp}" \
RUN_LOG_FILE="${log_file}" \
MODEL_PATH="${model}" \
LLAMA_BIN_PATH="${llama_bench_bin}" \
RUN_COMMAND="${command_str% }" \
MODEL_DIR="${model_dir}" \
MODEL="${model}" \
LLAMA_CPP_BACKEND="${llama_cpp_backend}" \
LLAMA_BENCH_BIN="${llama_bench_bin}" \
LLAMA_BENCH_NGL="${ngl}" \
LLAMA_BENCH_THREADS="${threads}" \
LLAMA_BENCH_PG="${prompt_gen}" \
LLAMA_BENCH_BATCH="${batch_size}" \
LLAMA_BENCH_UBATCH="${ubatch_size}" \
LLAMA_BENCH_FA="${flash_attention}" \
"${capture_env_script}" "${capture_file}" >/dev/null

"${command[@]}" 2>&1 | tee "${log_file}"

exit "${PIPESTATUS[0]}"
