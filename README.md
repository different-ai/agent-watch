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
swift run screentext search "invoice"
swift run screentext ingest --text "manual line" --app "Notes"
swift run screentext status
swift run screentext purge --older-than 30d
```

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
