#!/usr/bin/env bash

trim_trailing_whitespace() {
	local value="$1"
	value="${value%"${value##*[![:space:]]}"}"
	printf '%s' "${value}"
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
			value="$(trim_trailing_whitespace "${value}")"
		fi

		printf -v "${key}" '%s' "${value}"
		export "${key}"
	done < "${env_file}"
}
