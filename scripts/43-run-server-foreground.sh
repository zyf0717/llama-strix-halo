#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
server_id="${1:-}"
shift || true

if [[ -z "${server_id}" ]]; then
	echo "usage: $(basename "$0") <server-id> [llama-server args...]" >&2
	exit 2
fi

if [[ ! "${server_id}" =~ ^[A-Za-z0-9._-]+$ ]]; then
	echo "invalid server id: ${server_id}" >&2
	exit 2
fi

LLAMA_SERVER_FOREGROUND=1 exec "${script_dir}/40-restart-servers.sh" "${server_id}" "$@"
