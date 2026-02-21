#!/usr/bin/env bash
set -euo pipefail

nohup swift run agent-watch daemon > "/tmp/agent-watch-daemon.log" 2>&1 &
echo "agent-watch daemon started (log: /tmp/agent-watch-daemon.log)"
