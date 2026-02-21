#!/usr/bin/env bash
set -euo pipefail

host="${1:-127.0.0.1}"
port="${2:-41733}"

nohup swift run agent-watch serve --host "$host" --port "$port" > "/tmp/agent-watch-api.log" 2>&1 &
echo "agent-watch API started at http://$host:$port (log: /tmp/agent-watch-api.log)"
