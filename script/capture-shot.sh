#!/usr/bin/env bash
set -euo pipefail

# capture-shot.sh — screenshot the Termy window running in dev capture mode.
#
# Usage:
#   script/capture-shot.sh [outfile.png]   take a screenshot (default: /tmp/termy-shot-<ts>.png)
#   script/capture-shot.sh stop            kill the capture-mode app AND disconnect the virtual display
#
# Prereq: Termy already launched in capture mode (script/build_and_run.sh capture),
# which connects the virtual display and publishes the window-id.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WINDOWID_FILE="${TERMY_CAPTURE_WINDOWID_FILE:-/tmp/termy-capture-windowid}"

if [[ "${1:-}" == "stop" ]]; then
  pkill -f "$ROOT_DIR/dist/Termy.app/Contents/MacOS/Termy" >/dev/null 2>&1 || true
  rm -f "$WINDOWID_FILE"
  "$ROOT_DIR/script/capture-display.sh" disconnect
  exit 0
fi

OUT="${1:-/tmp/termy-shot-$(date +%s).png}"

if [[ ! -r "$WINDOWID_FILE" ]]; then
  echo "error: $WINDOWID_FILE not found — is Termy running in capture mode?" >&2
  echo "       launch it with: script/build_and_run.sh capture" >&2
  exit 1
fi

WID="$(tr -dc '0-9' < "$WINDOWID_FILE")"
if [[ -z "$WID" ]]; then
  echo "error: no window id in $WINDOWID_FILE" >&2
  exit 1
fi

# -x silent, -o no window shadow, -l capture exactly this window (no desktop margin).
screencapture -x -o -l "$WID" "$OUT"
echo "$OUT"
