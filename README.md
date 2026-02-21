# screentext

Swift-native, Apple Silicon-only macOS screen text memory.

## What it does

- Captures text from your active screen context.
- Uses Accessibility APIs first, Vision OCR fallback second.
- Stores text and metadata only in local SQLite (FTS5 search).
- Ships CLI-first (`screentext`) with launchd daemon support.

No audio, no screenshot storage, no cloud dependency.

## Requirements

- macOS 13+
- Apple Silicon (arm64)
- Swift 6.2+

## Build

```bash
swift build
```

## CLI usage

```bash
swift run screentext help
```

Common commands:

```bash
swift run screentext doctor
swift run screentext capture-once
swift run screentext capture-once --force-ocr
swift run screentext search "invoice"
swift run screentext ingest --text "manual line" --app "Notes"
swift run screentext status
swift run screentext purge --older-than 30d
```

## Local HTTP API

Start API server (loopback-only by default):

```bash
swift run screentext serve --host 127.0.0.1 --port 41733
```

Routes:

- `GET /health`
- `GET /status`
- `GET /search?q=<query>&limit=<n>&app=<name>`
- `GET /screen-recording/probe`

Examples:

```bash
curl -s "http://127.0.0.1:41733/health"
curl -s "http://127.0.0.1:41733/status"
curl -s "http://127.0.0.1:41733/search?q=invoice&limit=10"
curl -s "http://127.0.0.1:41733/screen-recording/probe"
```

Screen recording proof from CLI:

```bash
swift run screentext doctor
```

`doctor` prints permission status and a frame probe summary (resolution, byte count, and sample hash prefix).

## Data directory

Default:

`~/Library/Application Support/ScreenText/`

Override for tests or local sandbox:

```bash
SCREENTEXT_DATA_DIR=/tmp/screentext swift run screentext status
```

## Tests

Run unit/integration tests:

```bash
swift test
```

Run end-to-end CLI flow:

```bash
bash scripts/e2e.sh
```
