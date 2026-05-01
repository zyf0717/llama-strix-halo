#!/usr/bin/env bash
set -euo pipefail

# scripts/21-build-hip.sh
#
# Streamlined llama.cpp HIP/ROCm build script for Strix Halo.
#
# Expected repo layout:
#
# strix-halo-llamacpp-bench/
# ├─ scripts/21-build-hip.sh
# └─ third_party/llama.cpp/
#
# Usage:
#   ./scripts/21-build-hip.sh
#
# Optional:
#   CLEAN=1 ./scripts/21-build-hip.sh
#   DRY_RUN=1 ./scripts/21-build-hip.sh
#   BUILD_TYPE=RelWithDebInfo ./scripts/21-build-hip.sh
#   AMDGPU_TARGETS="gfx1151" ./scripts/21-build-hip.sh
#   ENABLE_ROCWMMA_FATTN=OFF ./scripts/21-build-hip.sh
#   ENABLE_HIP_MMQ_MFMA=OFF ./scripts/21-build-hip.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

LLAMA_DIR="$REPO_ROOT/third_party/llama.cpp"
BUILD_DIR="$LLAMA_DIR/build-hip"
FETCH_SCRIPT="$REPO_ROOT/scripts/10-fetch-llamacpp.sh"

BUILD_TYPE="${BUILD_TYPE:-Release}"
CLEAN="${CLEAN:-0}"
DRY_RUN="${DRY_RUN:-0}"

# Strix Halo / Ryzen AI Max+ 395 iGPU target.
# Override if building for another AMD GPU.
AMDGPU_TARGETS="${AMDGPU_TARGETS:-gfx1151}"

ENABLE_ROCWMMA_FATTN="${ENABLE_ROCWMMA_FATTN:-ON}"
ENABLE_HIP_MMQ_MFMA="${ENABLE_HIP_MMQ_MFMA:-ON}"
ENABLE_BACKEND_DL="${ENABLE_BACKEND_DL:-ON}"
ENABLE_CPU_VARIANTS="${ENABLE_CPU_VARIANTS:-ON}"
ENABLE_LLAMA_CURL="${ENABLE_LLAMA_CURL:-ON}"

run() {
	printf '+'
	printf ' %q' "$@"
	echo

	if [[ "$DRY_RUN" != "1" ]]; then
		"$@"
	fi
}

require_on_off() {
	local name="$1"
	local value="$2"

	case "$value" in
		ON|OFF) ;;
		*)
			echo "ERROR: $name must be ON or OFF, got: $value"
			exit 1
			;;
	esac
}

validate_config() {
	require_on_off ENABLE_ROCWMMA_FATTN "$ENABLE_ROCWMMA_FATTN"
	require_on_off ENABLE_HIP_MMQ_MFMA "$ENABLE_HIP_MMQ_MFMA"
	require_on_off ENABLE_BACKEND_DL "$ENABLE_BACKEND_DL"
	require_on_off ENABLE_CPU_VARIANTS "$ENABLE_CPU_VARIANTS"
	require_on_off ENABLE_LLAMA_CURL "$ENABLE_LLAMA_CURL"

	case "$BUILD_TYPE" in
		Release|RelWithDebInfo|Debug|MinSizeRel) ;;
		*)
			echo "ERROR: unsupported BUILD_TYPE: $BUILD_TYPE"
			exit 1
			;;
	esac
}

echo "Repo root:              $REPO_ROOT"
echo "llama.cpp dir:          $LLAMA_DIR"
echo "Build dir:              $BUILD_DIR"
echo "Build type:             $BUILD_TYPE"
echo "DRY_RUN:                $DRY_RUN"
echo "AMDGPU_TARGETS:         $AMDGPU_TARGETS"
echo "rocWMMA FlashAttention: $ENABLE_ROCWMMA_FATTN"
echo "HIP MMQ MFMA:           $ENABLE_HIP_MMQ_MFMA"
echo "Backend DL:             $ENABLE_BACKEND_DL"
echo "CPU variants:           $ENABLE_CPU_VARIANTS"
echo "LLAMA_CURL:             $ENABLE_LLAMA_CURL"
echo

setup_rocm_env() {
	# Many ROCm installs put hipcc here without adding it to PATH.
	if [[ -d /opt/rocm/bin ]]; then
		export PATH="/opt/rocm/bin:$PATH"
	fi

	if [[ -d /opt/rocm/lib ]]; then
		export LD_LIBRARY_PATH="/opt/rocm/lib:${LD_LIBRARY_PATH:-}"
	fi

	if [[ -d /opt/rocm/lib64 ]]; then
		export LD_LIBRARY_PATH="/opt/rocm/lib64:${LD_LIBRARY_PATH:-}"
	fi
}

ensure_llamacpp() {
	if [[ ! -x "$FETCH_SCRIPT" ]]; then
		echo "ERROR: missing helper script: $FETCH_SCRIPT"
		exit 1
	fi

	echo "Ensuring pinned llama.cpp checkout..."
	run "$FETCH_SCRIPT"
	echo
}

check_hip_tools() {
	echo "Checking HIP/ROCm tools..."

	if ! command -v hipcc >/dev/null 2>&1; then
		if [[ "$DRY_RUN" == "1" ]]; then
			echo "DRY_RUN=1 set; hipcc not found, skipping HIP tool validation."
			echo
			return
		fi

		echo "ERROR: hipcc not found."
		echo "Run scripts/01-install-rocm-ubuntu.sh first, then reboot or log out/in."
		echo "Common path: /opt/rocm/bin/hipcc"
		exit 1
	fi

	echo "hipcc:"
	hipcc --version || true
	echo

	if command -v hipconfig >/dev/null 2>&1; then
		echo "hipconfig:"
		hipconfig --version || true
		echo
	else
		echo "WARNING: hipconfig not found."
		echo
	fi

	if command -v rocminfo >/dev/null 2>&1; then
		echo "rocminfo device summary:"

		tmp_out="$(mktemp)"
		tmp_err="$(mktemp)"

		if rocminfo >"$tmp_out" 2>"$tmp_err"; then
			grep -E "Name: *gfx|Marketing Name|Uuid:" "$tmp_out" | head -n 40 || true

			detected_gfx="$(
				grep -E "Name: *gfx" "$tmp_out" \
					| awk '{print $2}' \
					| sort -u \
					| tr '\n' ' ' \
					| sed 's/[[:space:]]*$//'
			)"

			if [[ -n "$detected_gfx" ]]; then
				echo
				echo "Detected gfx targets: $detected_gfx"

				if [[ "$detected_gfx" != *"$AMDGPU_TARGETS"* ]]; then
					echo "WARNING: AMDGPU_TARGETS=$AMDGPU_TARGETS does not appear in rocminfo output."
					echo "         This may be fine for cross-builds, but for Strix Halo you usually want gfx1151."
				fi
			fi
		else
			echo "WARNING: rocminfo failed; device visibility may be limited."
			cat "$tmp_err" || true
		fi

		rm -f "$tmp_out" "$tmp_err"
		echo
	else
		echo "WARNING: rocminfo not found; cannot verify GPU visibility."
		echo
	fi
}

clean_if_requested() {
	if [[ "$CLEAN" == "1" ]]; then
		echo "CLEAN=1 set; removing $BUILD_DIR"
		run rm -rf "$BUILD_DIR"
		echo
	fi
}

configure_build() {
	echo "Configuring llama.cpp HIP build..."

	cmake_args=(
		-S "$LLAMA_DIR"
		-B "$BUILD_DIR"
		-G Ninja
		-DCMAKE_BUILD_TYPE="$BUILD_TYPE"

		-DGGML_HIP=ON
		-DAMDGPU_TARGETS="$AMDGPU_TARGETS"

		-DGGML_HIP_ROCWMMA_FATTN="$ENABLE_ROCWMMA_FATTN"
		-DGGML_HIP_MMQ_MFMA="$ENABLE_HIP_MMQ_MFMA"

		-DGGML_BACKEND_DL="$ENABLE_BACKEND_DL"
		-DGGML_CPU_ALL_VARIANTS="$ENABLE_CPU_VARIANTS"

		-DLLAMA_CURL="$ENABLE_LLAMA_CURL"
		-DLLAMA_BUILD_TESTS=OFF
	)

	printf '  %q' cmake "${cmake_args[@]}"
	echo
	echo

	run cmake "${cmake_args[@]}"

	echo
}

compile_build() {
	echo "Building llama.cpp HIP backend..."

	run cmake --build "$BUILD_DIR" --config "$BUILD_TYPE" --parallel "$(nproc)"

	echo
}

print_result() {
	if [[ "$DRY_RUN" == "1" ]]; then
		echo "Dry run complete. No build commands were executed."
		echo
		return
	fi

	echo "Build complete."
	echo

	echo "llama.cpp commit:"
	git -C "$LLAMA_DIR" rev-parse HEAD || true
	echo

	echo "Binaries:"
	for bin in llama-cli llama-server llama-bench; do
		path="$BUILD_DIR/bin/$bin"
		if [[ -x "$path" ]]; then
			echo "  OK       $path"
		else
			echo "  MISSING  $path"
		fi
	done

	echo
	echo "Version check:"
	if [[ -x "$BUILD_DIR/bin/llama-cli" ]]; then
		"$BUILD_DIR/bin/llama-cli" --version || true
	fi

	echo
	echo "Runtime notes:"
	echo "  - Strix Halo target should usually be: AMDGPU_TARGETS=gfx1151"
	echo "  - Verify ROCm/HIP drivers with: rocminfo && hipcc --version"
	echo "  - To select devices, set: HIP_VISIBLE_DEVICES or ROCM_VISIBLE_DEVICES"
	echo "  - If rocWMMA causes build/runtime issues, retry:"
	echo "      CLEAN=1 ENABLE_ROCWMMA_FATTN=OFF ./scripts/21-build-hip.sh"
	echo "  - If MMQ/MFMA causes issues, retry:"
	echo "      CLEAN=1 ENABLE_HIP_MMQ_MFMA=OFF ./scripts/21-build-hip.sh"
	echo
}

main() {
	validate_config
	setup_rocm_env
	ensure_llamacpp
	check_hip_tools
	clean_if_requested
	configure_build
	compile_build
	print_result
}

main "$@"
