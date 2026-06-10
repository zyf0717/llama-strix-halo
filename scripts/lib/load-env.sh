#!/usr/bin/env bash

trim_trailing_whitespace() {
	local value="$1"
	value="${value%"${value##*[![:space:]]}"}"
	printf '%s' "${value}"
}

strip_unquoted_inline_comment() {
	local value="$1"
	local i
	local char
	local prev

	for ((i = 0; i < ${#value}; i++)); do
		char="${value:i:1}"
		if [[ "${char}" != "#" ]]; then
			continue
		fi

		if [[ "${i}" -eq 0 ]]; then
			printf '%s' ""
			return
		fi

		prev="${value:i-1:1}"
		if [[ "${prev}" =~ [[:space:]] ]]; then
			trim_trailing_whitespace "${value:0:i}"
			return
		fi
	done

	printf '%s' "${value}"
}

resolve_llama_cpp_build_dir() {
	local repo_root="$1"
	local backend="${2:-hip}"

	case "${backend}" in
		hip)
			printf '%s' "${repo_root}/third_party/llama.cpp/build-hip"
			;;
		vulkan)
			printf '%s' "${repo_root}/third_party/llama.cpp/build-vulkan"
			;;
		*)
			echo "unsupported LLAMA_CPP_BACKEND: ${backend} (expected: hip or vulkan)" >&2
			return 1
			;;
	esac
}

load_env_file() {
	local env_file="${1:-.env}"
	local line=""
	local line_no=0
	local key=""
	local value=""

	[[ -f "${env_file}" ]] || return 0

	while IFS= read -r line || [[ -n "${line}" ]]; do
		line_no=$((line_no + 1))
		line="${line%$'\r'}"

		[[ "${line}" =~ ^[[:space:]]*$ ]] && continue
		[[ "${line}" =~ ^[[:space:]]*# ]] && continue

		if [[ ! "${line}" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
			echo "invalid env line in ${env_file}:${line_no}: ${line}" >&2
			return 1
		fi

		key="${BASH_REMATCH[2]}"
		value="${BASH_REMATCH[3]}"
		value="${value#"${value%%[![:space:]]*}"}"

		if [[ "${value}" =~ ^\"(.*)\"[[:space:]]*$ ]]; then
			value="${BASH_REMATCH[1]}"
			value="${value//\\\"/\"}"
			value="${value//\\\\/\\}"
		elif [[ "${value}" =~ ^\'(.*)\'[[:space:]]*$ ]]; then
			value="${BASH_REMATCH[1]}"
		else
			value="$(strip_unquoted_inline_comment "${value}")"
			value="$(trim_trailing_whitespace "${value}")"
		fi

		printf -v "${key}" '%s' "${value}"
		export "${key}"
	done < "${env_file}"
}
