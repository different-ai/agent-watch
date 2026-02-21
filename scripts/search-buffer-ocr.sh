#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 ]]; then
  echo "Usage: bash scripts/search-buffer-ocr.sh \"query\" [--seconds N] [--limit N]" >&2
  exit 2
fi

swift run agent-watch search-buffer-ocr "$@"
