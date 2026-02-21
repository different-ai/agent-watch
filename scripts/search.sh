#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 ]]; then
  echo "Usage: bash scripts/search.sh \"query\" [--limit N] [--app AppName]" >&2
  exit 2
fi

swift run agent-watch search "$@"
