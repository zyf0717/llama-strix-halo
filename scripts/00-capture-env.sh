#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
default_results_dir="${repo_root}/results"

cd "${repo_root}"

results_dir="${RESULTS_DIR:-${default_results_dir}}"
output_file="${1:-${CAPTURE_ENV_OUT:-}}"
run_kind="${RUN_KIND:-unknown}"
run_timestamp="${RUN_TIMESTAMP:-$(date +%Y%m%d_%H%M%S)}"

if [[ -z "${output_file}" ]]; then
	output_file="${results_dir}/${run_timestamp}.env.txt"
fi

mkdir -p "$(dirname -- "${output_file}")"

write_kv() {
	local key="$1"
	local value="${2:-}"
	printf '%s=%s\n' "${key}" "${value}"
}

write_section() {
	local title="$1"
	printf '\n[%s]\n' "${title}"
}

maybe_run() {
	[[ $# -gt 0 ]] || return 0
	[[ -n "${1}" ]] || return 0

	if ! command -v "$1" >/dev/null 2>&1; then
		return 0
	fi

	printf '$ %s\n' "$*"
	"$@" 2>&1 || true
}

{
	write_section "run"
	write_kv "captured_at" "$(date -Is)"
	write_kv "run_kind" "${run_kind}"
	write_kv "run_timestamp" "${run_timestamp}"
	write_kv "cwd" "${repo_root}"
	write_kv "log_file" "${RUN_LOG_FILE:-}"
	write_kv "model" "${MODEL_PATH:-}"
	write_kv "llama_bin" "${LLAMA_BIN_PATH:-}"
	write_kv "command" "${RUN_COMMAND:-}"

	write_section "git"
	write_kv "repo_head" "$(git rev-parse HEAD 2>/dev/null || true)"
	write_kv "repo_branch" "$(git branch --show-current 2>/dev/null || true)"
	write_kv "repo_dirty" "$([[ -n "$(git status --porcelain 2>/dev/null || true)" ]] && echo yes || echo no)"
	write_kv "llamacpp_head" "$(git -C third_party/llama.cpp rev-parse HEAD 2>/dev/null || true)"
	write_kv "llamacpp_submodule" "$(git submodule status -- third_party/llama.cpp 2>/dev/null || true)"
	maybe_run git status --short

	write_section "runtime_env"
	write_kv "AMD_VULKAN_ICD" "${AMD_VULKAN_ICD:-}"
	write_kv "GGML_LOG_LEVEL" "${GGML_LOG_LEVEL:-}"
	write_kv "GGML_VK_VISIBLE_DEVICES" "${GGML_VK_VISIBLE_DEVICES:-}"
	write_kv "MODEL_DIR" "${MODEL_DIR:-}"
	write_kv "MODEL" "${MODEL:-}"
	write_kv "LLAMACPP_REF" "${LLAMACPP_REF:-}"
	write_kv "LLAMA_BENCH_BIN" "${LLAMA_BENCH_BIN:-}"
	write_kv "LLAMA_BENCH_NGL" "${LLAMA_BENCH_NGL:-}"
	write_kv "LLAMA_BENCH_THREADS" "${LLAMA_BENCH_THREADS:-}"
	write_kv "LLAMA_BENCH_PG" "${LLAMA_BENCH_PG:-}"
	write_kv "LLAMA_BENCH_BATCH" "${LLAMA_BENCH_BATCH:-}"
	write_kv "LLAMA_BENCH_UBATCH" "${LLAMA_BENCH_UBATCH:-}"
	write_kv "LLAMA_BENCH_FA" "${LLAMA_BENCH_FA:-}"
	write_kv "LLAMA_SERVER_BIN" "${LLAMA_SERVER_BIN:-}"
	write_kv "LLAMA_SERVER_NGL" "${LLAMA_SERVER_NGL:-}"
	write_kv "LLAMA_SERVER_CTX" "${LLAMA_SERVER_CTX:-}"
	write_kv "LLAMA_SERVER_THREADS" "${LLAMA_SERVER_THREADS:-}"
	write_kv "LLAMA_SERVER_BATCH" "${LLAMA_SERVER_BATCH:-}"
	write_kv "LLAMA_SERVER_UBATCH" "${LLAMA_SERVER_UBATCH:-}"
	write_kv "LLAMA_SERVER_HOST" "${LLAMA_SERVER_HOST:-}"
	write_kv "LLAMA_SERVER_PORT" "${LLAMA_SERVER_PORT:-}"
	write_kv "LLAMA_SERVER_ALIAS" "${LLAMA_SERVER_ALIAS:-}"
	write_kv "LLAMA_SERVER_FLASH_ATTN" "${LLAMA_SERVER_FLASH_ATTN:-}"

	write_section "system"
	maybe_run uname -a
	maybe_run hostnamectl
	maybe_run lscpu
	maybe_run free -h
	maybe_run lsb_release -a

	write_section "gpu"
	maybe_run lspci
	maybe_run rocminfo
	maybe_run rocm-smi
	maybe_run nvidia-smi

	write_section "vulkan"
	maybe_run vulkaninfo --summary

	write_section "llama_binaries"
	maybe_run "${LLAMA_BIN_PATH:-}" --version
	maybe_run "${LLAMA_BENCH_BIN:-}" --version
	maybe_run "${LLAMA_SERVER_BIN:-}" --version
} > "${output_file}"

echo "${output_file}"
