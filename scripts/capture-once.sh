#!/usr/bin/env bash
set -euo pipefail

swift run agent-watch capture-once "$@"
