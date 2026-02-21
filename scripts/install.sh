#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/different-ai/agent-watch.git"
INSTALL_ROOT="${AGENT_WATCH_INSTALL_ROOT:-$HOME/.agent-watch}"
SRC_DIR="$INSTALL_ROOT/src"
BIN_DIR="${AGENT_WATCH_BIN_DIR:-$HOME/.local/bin}"
INSTALL_LAUNCHD="${AGENT_WATCH_INSTALL_LAUNCHD:-0}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "agent-watch supports macOS only." >&2
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "agent-watch currently supports Apple Silicon only (arm64)." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required but was not found." >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift toolchain is required but was not found." >&2
  exit 1
fi

mkdir -p "$INSTALL_ROOT"

if [[ -d "$SRC_DIR/.git" ]]; then
  echo "Updating existing checkout at $SRC_DIR"
  git -C "$SRC_DIR" fetch origin
  git -C "$SRC_DIR" pull --ff-only origin main
else
  echo "Cloning $REPO_URL to $SRC_DIR"
  git clone "$REPO_URL" "$SRC_DIR"
fi

echo "Building release binary"
swift build --configuration release --package-path "$SRC_DIR"

mkdir -p "$BIN_DIR"
cp "$SRC_DIR/.build/release/agent-watch" "$BIN_DIR/agent-watch"
chmod +x "$BIN_DIR/agent-watch"

echo "Installed: $BIN_DIR/agent-watch"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo ""
  echo "Add to PATH:"
  echo "  export PATH=\"$BIN_DIR:\$PATH\""
fi

echo ""
echo "Running doctor"
"$BIN_DIR/agent-watch" doctor || true

if [[ "$INSTALL_LAUNCHD" == "1" ]]; then
  echo ""
  echo "Installing launchd agent"
  "$BIN_DIR/agent-watch" install
fi

echo ""
echo "First-time permissions (if needed):"
echo "  open \"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\""
echo "  open \"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture\""
echo ""
echo "Quick start:"
echo "  agent-watch capture-once"
echo "  agent-watch serve --host 127.0.0.1 --port 41733"
