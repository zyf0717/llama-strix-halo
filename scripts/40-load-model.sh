#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
default_model_dir="${repo_root}/models"
default_model_name="gpt-oss-120b-MXFP4-00001-of-00002.gguf"
default_logs_dir="${repo_root}/logs"
capture_env_script="${repo_root}/scripts/00-capture-env.sh"

source "${script_dir}/lib/load-env.sh"

cd "${repo_root}"
load_env_file "${repo_root}/.env"

llama_cpp_backend="${LLAMA_CPP_BACKEND:-vulkan}"

export GGML_VK_VISIBLE_DEVICES="${GGML_VK_VISIBLE_DEVICES:-0}"
export AMD_VULKAN_ICD="${AMD_VULKAN_ICD:-RADV}"

model_dir="${MODEL_DIR:-${default_model_dir}}"
model="${MODEL:-${model_dir}/${default_model_name}}"
if [[ -n "${LLAMA_SERVER_BIN:-}" ]]; then
	llama_server_bin="${LLAMA_SERVER_BIN}"
else
	llama_cpp_build_dir="$(resolve_llama_cpp_build_dir "${repo_root}" "${llama_cpp_backend}")"
	llama_server_bin="${llama_cpp_build_dir}/bin/llama-server"
fi
output_dir="${LLAMA_SERVER_RESULTS_DIR:-${RESULTS_DIR:-${default_logs_dir}}}"
ngl="${LLAMA_SERVER_NGL:-999}"
context_size="${LLAMA_SERVER_CTX:-130000}"
threads="${LLAMA_SERVER_THREADS:-8}"
batch_size="${LLAMA_SERVER_BATCH:-2048}"
ubatch_size="${LLAMA_SERVER_UBATCH:-2048}"
host="${LLAMA_SERVER_HOST:-127.0.0.1}"
port="${LLAMA_SERVER_PORT:-1234}"
alias_name="${LLAMA_SERVER_ALIAS:-OpenAI/gpt-oss-120b-MXFP4}"
flash_attn="${LLAMA_SERVER_FLASH_ATTN:-on}"
server_extra_args_raw="${LLAMA_SERVER_EXTRA_ARGS:-}"
timestamp="$(date +%Y%m%d_%H%M%S)"
log_file="${output_dir}/${timestamp}.log"
capture_file="${output_dir}/${timestamp}.env.txt"

server_extra_args=()
if [[ -n "${server_extra_args_raw}" ]]; then
	# Allow simple space-delimited extra llama-server flags from .env.
	read -r -a server_extra_args <<< "${server_extra_args_raw}"
fi

if [[ ! -x "${llama_server_bin}" ]]; then
	echo "llama-server binary not found or not executable: ${llama_server_bin}" >&2
	exit 1
fi

if [[ ! -e "${model}" ]]; then
	echo "model not found: ${model}" >&2
	exit 1
fi

mkdir -p "${output_dir}"

stop_previous_server() {
	local pid
	while IFS= read -r pid; do
		[[ -n "${pid}" ]] || continue
		if ! kill -0 "${pid}" 2>/dev/null; then
			continue
		fi

		echo "stopping previous llama-server PID ${pid}"
		kill -15 "${pid}" 2>/dev/null || true

		for _ in {1..20}; do
			if ! kill -0 "${pid}" 2>/dev/null; then
				break
			fi
			sleep 0.25
		done

		if kill -0 "${pid}" 2>/dev/null; then
			echo "force killing previous llama-server PID ${pid}"
			kill -9 "${pid}" 2>/dev/null || true
		fi
	done < <(
		ps -eo pid=,args= | awk -v bin="${llama_server_bin}" -v port="${port}" '
			$2 != bin { next }
			{
				for (i = 3; i < NF; i++) {
					if ($i == "--port" && $(i + 1) == port) {
						print $1
						break
					}
				}
			}
		'
	)
}

stop_previous_server

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
	"${server_extra_args[@]}"
	"$@"
)

printf -v command_str '%q ' "${command[@]}"

RUN_KIND=server \
RUN_TIMESTAMP="${timestamp}" \
RUN_LOG_FILE="${log_file}" \
RUN_OUTPUT_DIR="${output_dir}" \
MODEL_PATH="${model}" \
LLAMA_BIN_PATH="${llama_server_bin}" \
RUN_COMMAND="${command_str% }" \
MODEL_DIR="${model_dir}" \
MODEL="${model}" \
LLAMA_CPP_BACKEND="${llama_cpp_backend}" \
RESULTS_DIR="${RESULTS_DIR:-}" \
LLAMA_SERVER_BIN="${llama_server_bin}" \
LLAMA_SERVER_RESULTS_DIR="${output_dir}" \
LLAMA_SERVER_NGL="${ngl}" \
LLAMA_SERVER_CTX="${context_size}" \
LLAMA_SERVER_THREADS="${threads}" \
LLAMA_SERVER_BATCH="${batch_size}" \
LLAMA_SERVER_UBATCH="${ubatch_size}" \
LLAMA_SERVER_HOST="${host}" \
LLAMA_SERVER_PORT="${port}" \
LLAMA_SERVER_ALIAS="${alias_name}" \
LLAMA_SERVER_FLASH_ATTN="${flash_attn}" \
LLAMA_SERVER_EXTRA_ARGS="${server_extra_args_raw}" \
"${capture_env_script}" "${capture_file}" >/dev/null

"${command[@]}" > "${log_file}" 2>&1 &
server_pid=$!

echo "llama-server started with PID ${server_pid}"
echo "log file: ${log_file}"
echo "env capture: ${capture_file}"
