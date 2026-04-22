#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
default_model_dir="${repo_root}/models"
default_model="${default_model_dir}/Qwen_Qwen3-Coder-Next-Q5_K_M-00001-of-00002.gguf"
default_llama_server_bin="${repo_root}/third_party/llama.cpp/build-vulkan/bin/llama-server"
default_results_dir="${repo_root}/results"

cd "${repo_root}"

if [[ -f .env ]]; then
	set -a
	# shellcheck disable=SC1091
	source .env
	set +a
fi

export GGML_VK_VISIBLE_DEVICES="${GGML_VK_VISIBLE_DEVICES:-0}"
export AMD_VULKAN_ICD="${AMD_VULKAN_ICD:-RADV}"

model_dir="${MODEL_DIR:-${default_model_dir}}"
model="${MODEL:-${default_model}}"
llama_server_bin="${LLAMA_SERVER_BIN:-${default_llama_server_bin}}"
results_dir="${RESULTS_DIR:-${default_results_dir}}"
ngl="${LLAMA_SERVER_NGL:-999}"
context_size="${LLAMA_SERVER_CTX:-130000}"
threads="${LLAMA_SERVER_THREADS:-8}"
batch_size="${LLAMA_SERVER_BATCH:-2048}"
ubatch_size="${LLAMA_SERVER_UBATCH:-2048}"
host="${LLAMA_SERVER_HOST:-127.0.0.1}"
port="${LLAMA_SERVER_PORT:-1234}"
alias_name="${LLAMA_SERVER_ALIAS:-Qwen/Qwen3-Coder-Next-Q5_K_M}"
flash_attn="${LLAMA_SERVER_FLASH_ATTN:-on}"
timestamp="$(date +%Y%m%d_%H%M%S)"
log_file="${results_dir}/${timestamp}.log"

if [[ ! -x "${llama_server_bin}" ]]; then
	echo "llama-server binary not found or not executable: ${llama_server_bin}" >&2
	exit 1
fi

if [[ ! -e "${model}" ]]; then
	echo "model not found: ${model}" >&2
	exit 1
fi

mkdir -p "${results_dir}"

command=(
	nohup
	"${llama_server_bin}"
	-m "${model}"
	-ngl "${ngl}"
	-c "${context_size}"
	--flash-attn "${flash_attn}"
	-t "${threads}"
	-b "${batch_size}"
	-ub "${ubatch_size}"
	--host "${host}"
	--port "${port}"
	--jinja
	-a "${alias_name}"
	"$@"
)

"${command[@]}" > "${log_file}" 2>&1 &
server_pid=$!

echo "llama-server started with PID ${server_pid}"
echo "log file: ${log_file}"