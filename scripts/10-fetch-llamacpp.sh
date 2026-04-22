#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
submodule_path="third_party/llama.cpp"
submodule_url="https://github.com/ggml-org/llama.cpp"
default_llamacpp_ref="0dedb9ef7a71fcebfa6fb17e0d6e6abd6e893376"

source "${script_dir}/lib/load-env.sh"

cd "${repo_root}"
load_env_file "${repo_root}/.env"

llamacpp_ref="${LLAMACPP_REF:-${default_llamacpp_ref}}"

if git config --file .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print $2}' | grep -Fxq "${submodule_path}"; then
	git submodule sync -- "${submodule_path}"
	git submodule update --init --recursive -- "${submodule_path}"
	git -C "${submodule_path}" fetch --tags origin
	git -C "${submodule_path}" checkout --detach "${llamacpp_ref}"
	exit 0
fi

if [[ -d "${submodule_path}" ]] && [[ -z "$(find "${submodule_path}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
	rmdir "${submodule_path}"
fi

git submodule add "${submodule_url}" "${submodule_path}"
git submodule update --init --recursive -- "${submodule_path}"
git -C "${submodule_path}" fetch --tags origin
git -C "${submodule_path}" checkout --detach "${llamacpp_ref}"
