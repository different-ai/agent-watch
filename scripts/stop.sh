#!/usr/bin/env bash
set -euo pipefail

pkill -f "swift run agent-watch daemon" || true
pkill -f "swift run agent-watch serve" || true
echo "agent-watch background processes stopped"
