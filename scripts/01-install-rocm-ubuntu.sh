#!/usr/bin/env bash
set -euo pipefail

# scripts/01-install-rocm-ubuntu.sh
#
# Ubuntu ROCm/HIP installer for llama.cpp HIP builds on Strix Halo.
#
# Usage:
#   ./scripts/01-install-rocm-ubuntu.sh
#
# Optional:
#   DRY_RUN=1 ./scripts/01-install-rocm-ubuntu.sh
#   SKIP_APT=1 ./scripts/01-install-rocm-ubuntu.sh
#   INSTALL_FULL_ROCM=1 ./scripts/01-install-rocm-ubuntu.sh
#   ROCM_VERSION=7.2.2 ./scripts/01-install-rocm-ubuntu.sh
#   ROCM_GRAPHICS_VERSION=7.2.1 ./scripts/01-install-rocm-ubuntu.sh

DRY_RUN="${DRY_RUN:-0}"
SKIP_APT="${SKIP_APT:-0}"
INSTALL_FULL_ROCM="${INSTALL_FULL_ROCM:-0}"
ROCM_VERSION="${ROCM_VERSION:-7.2.2}"
ROCM_GRAPHICS_VERSION="${ROCM_GRAPHICS_VERSION:-7.2.1}"

run() {
	printf '+'
	printf ' %q' "$@"
	echo

	if [[ "$DRY_RUN" != "1" ]]; then
		"$@"
	fi
}

require_apt() {
	if ! command -v apt-get >/dev/null 2>&1; then
		echo "ERROR: apt-get not found. This installer supports Ubuntu/Debian apt-based systems only."
		exit 1
	fi
}

detect_ubuntu_codename() {
	if [[ ! -r /etc/os-release ]]; then
		echo "ERROR: cannot read /etc/os-release."
		exit 1
	fi

	# shellcheck disable=SC1091
	. /etc/os-release

	case "${VERSION_CODENAME:-}" in
		noble|jammy)
			ubuntu_codename="$VERSION_CODENAME"
			;;
		*)
			echo "ERROR: unsupported Ubuntu codename: ${VERSION_CODENAME:-unknown}"
			echo "Supported by this script: noble, jammy."
			exit 1
			;;
	esac
}

install_base_deps() {
	if [[ "$SKIP_APT" == "1" ]]; then
		echo "SKIP_APT=1 set; skipping apt dependency install."
		return
	fi

	echo "Installing build and ROCm repository dependencies..."

	run sudo apt-get update
	run sudo apt-get install -y \
		git \
		build-essential \
		cmake \
		ninja-build \
		pkg-config \
		ca-certificates \
		curl \
		wget \
		gpg \
		libcurl4-openssl-dev \
		libnuma-dev \
		libgomp1 \
		clang \
		python3 \
		python3-pip \
		python3-setuptools \
		python3-wheel

	echo
}

configure_rocm_repo() {
	echo "Configuring ROCm $ROCM_VERSION apt repositories for Ubuntu $ubuntu_codename..."

	run sudo mkdir --parents --mode=0755 /etc/apt/keyrings

	if [[ "$DRY_RUN" == "1" ]]; then
		echo "+ wget https://repo.radeon.com/rocm/rocm.gpg.key -O - | gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg >/dev/null"
		echo "+ sudo tee /etc/apt/sources.list.d/rocm.list >/dev/null"
		echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/${ROCM_VERSION} ${ubuntu_codename} main"
		echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/graphics/${ROCM_GRAPHICS_VERSION}/ubuntu ${ubuntu_codename} main"
		echo "+ sudo tee /etc/apt/preferences.d/rocm-pin-600 >/dev/null"
		echo "Package: *"
		echo "Pin: origin repo.radeon.com"
		echo "Pin-Priority: 600"
	else
		wget https://repo.radeon.com/rocm/rocm.gpg.key -O - \
			| gpg --dearmor \
			| sudo tee /etc/apt/keyrings/rocm.gpg >/dev/null

		sudo tee /etc/apt/sources.list.d/rocm.list >/dev/null <<EOF
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/${ROCM_VERSION} ${ubuntu_codename} main
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/graphics/${ROCM_GRAPHICS_VERSION}/ubuntu ${ubuntu_codename} main
EOF

		sudo tee /etc/apt/preferences.d/rocm-pin-600 >/dev/null <<EOF
Package: *
Pin: origin repo.radeon.com
Pin-Priority: 600
EOF
	fi

	run sudo apt-get update
	echo
}

validate_rocm_candidates() {
	echo "Checking ROCm package candidates..."

	if [[ "$DRY_RUN" == "1" ]]; then
		echo "+ apt-cache policy rocminfo rocm-hip-runtime rocm-hip-sdk rocm"
		echo "+ apt-cache policy rocminfo | grep -q repo.radeon.com"
		echo
		return
	fi

	apt-cache policy rocminfo rocm-hip-runtime rocm-hip-sdk rocm || true
	echo

	if ! apt-cache policy rocminfo | grep -q "repo.radeon.com"; then
		echo "ERROR: rocminfo candidate is not coming from repo.radeon.com."
		echo "Run:"
		echo "  apt-cache policy rocminfo"
		echo
		echo "Fix ROCm repo pinning before continuing."
		exit 1
	fi
}

install_rocm_packages() {
	if [[ "$SKIP_APT" == "1" ]]; then
		echo "SKIP_APT=1 set; skipping ROCm package install."
		return
	fi

	echo "Installing ROCm/HIP build packages..."

	run sudo apt-get install -y \
		rocminfo \
		rocm-hip-runtime \
		rocm-hip-sdk

	if [[ "$INSTALL_FULL_ROCM" == "1" ]]; then
		echo
		echo "INSTALL_FULL_ROCM=1 set; installing full rocm meta-package..."
		run sudo apt-get install -y rocm
	fi

	echo
}

add_user_to_gpu_groups() {
	local target_user
	target_user="${SUDO_USER:-${USER:-$(id -un)}}"

	echo "Adding $target_user to render/video groups..."
	run sudo usermod -aG render,video "$target_user"
	echo
}

print_result() {
	echo "ROCm installer complete."
	echo
	echo "Next steps:"
	echo "  - Reboot or log out/in so render/video group membership applies."
	echo "  - Build llama.cpp HIP with: ./scripts/21-build-hip.sh"
	echo "  - Verify ROCm/HIP drivers with: rocminfo && hipcc --version"
}

main() {
	require_apt
	detect_ubuntu_codename
	install_base_deps
	configure_rocm_repo
	validate_rocm_candidates
	install_rocm_packages
	add_user_to_gpu_groups
	print_result
}

main "$@"
