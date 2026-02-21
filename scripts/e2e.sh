#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

export AGENT_WATCH_DATA_DIR="$TEMP_DIR/data"

swift build --configuration release --package-path "$ROOT_DIR" >/dev/null

BIN="$ROOT_DIR/.build/release/agent-watch"

"$BIN" ingest --text "invoice number 4832 from safari" --app "Safari" --window "Invoices"
"$BIN" ingest --text "compiler error unresolved identifier" --app "Xcode" --window "Build"

PORT="$((43000 + RANDOM % 1000))"
"$BIN" serve --port "$PORT" >"$TEMP_DIR/api.log" 2>&1 &
SERVER_PID="$!"

for _ in {1..40}; do
  if curl -s "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

HEALTH_OUT="$(curl -s "http://127.0.0.1:$PORT/health")"
[[ "$HEALTH_OUT" == *"\"ok\":true"* ]]

API_SEARCH="$(curl -s "http://127.0.0.1:$PORT/search?q=invoice&limit=5")"
[[ "$API_SEARCH" == *"invoice number 4832"* ]]

API_STATUS="$(curl -s "http://127.0.0.1:$PORT/status")"
[[ "$API_STATUS" == *"\"recordCount\":2"* ]]

API_PROBE="$(curl -s "http://127.0.0.1:$PORT/screen-recording/probe")"
[[ "$API_PROBE" == *"\"granted\":"* ]]
[[ "$API_PROBE" == *"\"width\":"* ]]

SEARCH_OUT="$("$BIN" search invoice --limit 5)"
[[ "$SEARCH_OUT" == *"invoice number 4832"* ]]

FILTERED_OUT="$("$BIN" search compiler --limit 5 --app Xcode)"
[[ "$FILTERED_OUT" == *"Xcode"* ]]

STATUS_OUT="$("$BIN" status)"
[[ "$STATUS_OUT" == *"Records: 2"* ]]

"$BIN" purge --older-than 0d >/dev/null
EMPTY_OUT="$("$BIN" search invoice --limit 5)"
[[ "$EMPTY_OUT" == *"No results."* ]]

echo "e2e: passed"
