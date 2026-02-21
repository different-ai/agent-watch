#!/usr/bin/env bash
set -euo pipefail

host="${1:-127.0.0.1}"
port="${2:-41733}"

bash "$(dirname "$0")/stop.sh"
bash "$(dirname "$0")/run-daemon.sh"
bash "$(dirname "$0")/run-api.sh" "$host" "$port"

echo "agent-watch restarted and healthy check:" 
curl -s "http://$host:$port/health" || true
