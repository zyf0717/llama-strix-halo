#!/usr/bin/env bash
set -euo pipefail

# scripts/20-build-vulkan.sh
#
# Streamlined llama.cpp Vulkan/RADV build script.
#
# Expected repo layout:
#
# strix-halo-llamacpp-bench/
# ├─ scripts/20-build-vulkan.sh
# └─ third_party/llama.cpp/
#
# Usage:
#   ./scripts/20-build-vulkan.sh
#
# Optional:
#   CLEAN=1 ./scripts/20-build-vulkan.sh
#   SKIP_APT=1 ./scripts/20-build-vulkan.sh
#   BUILD_TYPE=RelWithDebInfo ./scripts/20-build-vulkan.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

LLAMA_DIR="$REPO_ROOT/third_party/llama.cpp"
BUILD_DIR="$LLAMA_DIR/build-vulkan"

BUILD_TYPE="${BUILD_TYPE:-Release}"
CLEAN="${CLEAN:-0}"
SKIP_APT="${SKIP_APT:-0}"

echo "Repo root:     $REPO_ROOT"
echo "llama.cpp dir: $LLAMA_DIR"
echo "Build dir:     $BUILD_DIR"
echo "Build type:    $BUILD_TYPE"
echo

install_deps() {
  if [[ "$SKIP_APT" == "1" ]]; then
    echo "SKIP_APT=1 set; skipping apt dependency install."
    return
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "apt-get not found. Install dependencies manually, then rerun with SKIP_APT=1."
    exit 1
  fi

  echo "Installing build + Vulkan dependencies..."

  sudo apt-get update
  sudo apt-get install -y \
    git \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    ca-certificates \
    curl \
    libcurl4-openssl-dev \
    vulkan-tools \
    libvulkan-dev \
    mesa-vulkan-drivers \
    glslc \
    spirv-headers

  echo
}

ensure_llamacpp() {
  mkdir -p "$REPO_ROOT/third_party"

  if [[ -d "$LLAMA_DIR/.git" ]]; then
    echo "Found llama.cpp checkout."
    return
  fi

  if [[ -f "$REPO_ROOT/.gitmodules" ]] && grep -q "third_party/llama.cpp" "$REPO_ROOT/.gitmodules"; then
    echo "Initializing llama.cpp submodule..."
    git -C "$REPO_ROOT" submodule update --init --recursive third_party/llama.cpp
    return
  fi

  echo "No llama.cpp checkout or submodule found."
  echo "Cloning upstream llama.cpp into third_party/llama.cpp..."
  git clone https://github.com/ggml-org/llama.cpp.git "$LLAMA_DIR"
}

check_vulkan_tools() {
  echo "Checking Vulkan tools..."

  if ! command -v glslc >/dev/null 2>&1; then
    echo "ERROR: glslc not found."
    exit 1
  fi

  if ! command -v vulkaninfo >/dev/null 2>&1; then
    echo "ERROR: vulkaninfo not found."
    exit 1
  fi

  echo "glslc:"
  glslc --version | head -n 3 || true
  echo

  echo "vulkaninfo summary:"
  if vulkaninfo --summary >/tmp/vulkan-summary.txt 2>/tmp/vulkan-summary.err; then
    cat /tmp/vulkan-summary.txt
  else
    echo "WARNING: vulkaninfo --summary failed."
    echo "This can happen over SSH/headless sessions or if Vulkan/RADV is not visible."
    echo "stderr:"
    cat /tmp/vulkan-summary.err || true
  fi

  echo
}

clean_if_requested() {
  if [[ "$CLEAN" == "1" ]]; then
    echo "CLEAN=1 set; removing $BUILD_DIR"
    rm -rf "$BUILD_DIR"
    echo
  fi
}

configure_build() {
  echo "Configuring llama.cpp Vulkan build..."

  cmake -S "$LLAMA_DIR" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DGGML_VULKAN=ON \
    -DLLAMA_CURL=ON

  echo
}

compile_build() {
  echo "Building llama.cpp Vulkan backend..."

  cmake --build "$BUILD_DIR" --config "$BUILD_TYPE" -j"$(nproc)"

  echo
}

print_result() {
  echo "Build complete."
  echo

  echo "llama.cpp commit:"
  git -C "$LLAMA_DIR" rev-parse HEAD
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
  echo "For Strix Halo/RADV benchmark scripts, use runtime env vars like:"
  echo "  export AMD_VULKAN_ICD=RADV"
  echo "  export GGML_VK_VISIBLE_DEVICES=0"
  echo "  export GGML_LOG_LEVEL=2"
}

main() {
  install_deps
  ensure_llamacpp
  check_vulkan_tools
  clean_if_requested
  configure_build
  compile_build
  print_result
}

main "$@"