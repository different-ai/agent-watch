# agent-watch

Swift-native, Apple Silicon-only macOS screen text memory.

## What it does

- Captures text from your active screen context.
- Uses Accessibility APIs in the daemon by default.
- Uses Vision OCR on demand (`capture-now --force-ocr` or `search-buffer-ocr`).
- Stores text and metadata only in local SQLite (FTS5 search).
- Ships CLI-first (`agent-watch`) with launchd daemon support.
- Keeps a short rolling frame buffer to recover recent text after you switch away.

No audio, no screenshot storage, no cloud dependency.

## Requirements

- macOS 13+
- Apple Silicon (arm64)
- Swift 6.2+

## Easy install

One-command install (clone + build + install binary):

```bash
curl -fsSL https://raw.githubusercontent.com/different-ai/agent-watch/main/scripts/install.sh | bash
```

If you already cloned the repo:

```bash
bash scripts/install.sh
```

Optional persistent launchd install:

```bash
AGENT_WATCH_INSTALL_LAUNCHD=1 bash scripts/install.sh
```

## Low-CPU defaults (simple mode)

- Capture triggers: app switch + idle timer.
- Idle timer default: `30s`.
- Daemon OCR default: disabled (`ocr_enabled=false`).
- Rolling frame buffer: enabled, `5s` interval, `120s` retention.
- Retention default: `14` days.

## Build

```bash
swift build
```

## Skill-style helper scripts

The repo includes quick operational scripts adapted from the `agent-watch` skill:

```bash
bash scripts/build.sh
bash scripts/doctor.sh
bash scripts/capture-once.sh
bash scripts/search.sh "invoice"
bash scripts/search-buffer-ocr.sh "invoice" --seconds 120 --limit 10
bash scripts/run-daemon.sh
bash scripts/run-api.sh
bash scripts/restart.sh
bash scripts/stop.sh
```

## CLI usage

```bash
swift run agent-watch help
```

Common commands:

```bash
swift run agent-watch doctor
swift run agent-watch capture-once
swift run agent-watch capture-now
swift run agent-watch capture-once --force-ocr
swift run agent-watch search-buffer-ocr "alex" --seconds 120 --limit 10
swift run agent-watch search "invoice"
swift run agent-watch ingest --text "manual line" --app "Notes"
swift run agent-watch status
swift run agent-watch purge --older-than 30d
```

## Local HTTP API

Start API server (loopback-only by default):

```bash
swift run agent-watch serve --host 127.0.0.1 --port 41733
```

Routes:

- `GET /` (discovery)
- `GET /health`
- `GET /status`
- `GET /search?q=<query>&limit=<n>&app=<name>`
- `GET /screen-recording/probe`
- `GET /openapi.yaml`

Examples:

```bash
curl -s "http://127.0.0.1:41733/health"
curl -s "http://127.0.0.1:41733/"
curl -s "http://127.0.0.1:41733/status"
curl -s "http://127.0.0.1:41733/search?q=invoice&limit=10"
curl -s "http://127.0.0.1:41733/screen-recording/probe"
curl -s "http://127.0.0.1:41733/openapi.yaml"
```

API design and contract docs:

- `docs/api/openapi.yaml`
- `docs/api/INVARIANTS.md`
- `docs/api/TEST_MATRIX.md`

Screen recording proof from CLI:

```bash
swift run agent-watch doctor
```

`doctor` prints permission status and a frame probe summary (resolution, byte count, and sample hash prefix).

## Data directory

Default:

`~/Library/Application Support/AgentWatch/`

Override for tests or local sandbox:

```bash
AGENT_WATCH_DATA_DIR=/tmp/agent-watch swift run agent-watch status
```

Legacy fallback variable is also supported:

```bash
SCREENTEXT_DATA_DIR=/tmp/agent-watch swift run agent-watch status
```

## Practical OCR commands

Capture one immediate OCR snapshot:

```bash
agent-watch capture-now --force-ocr
```

Search recent buffered screenshots (on demand OCR):

```bash
agent-watch search-buffer-ocr "your phrase" --seconds 120 --limit 10
```

Useful config toggles:

```bash
agent-watch config set ocr_enabled false
agent-watch config set frame_buffer_interval_seconds 5
agent-watch config set frame_buffer_retention_seconds 120
agent-watch config set retention_days 14
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
