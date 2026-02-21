#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

export SCREENTEXT_DATA_DIR="$TEMP_DIR/data"

swift build --configuration release --package-path "$ROOT_DIR" >/dev/null

BIN="$ROOT_DIR/.build/release/screentext"

"$BIN" ingest --text "invoice number 4832 from safari" --app "Safari" --window "Invoices"
"$BIN" ingest --text "compiler error unresolved identifier" --app "Xcode" --window "Build"

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
