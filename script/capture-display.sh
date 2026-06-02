#!/usr/bin/env bash
set -euo pipefail

# capture-display.sh — manage the dedicated off-screen virtual display used by
# Termy's dev "capture mode" (see CaptureMode.swift / build_and_run.sh capture).
#
# WHY this exists: visual design passes build → launch → screenshot → kill the app
# repeatedly. Normally that steals focus and pops a window onto the user's desktop,
# making the Mac unusable in parallel. Capture mode parks the window on a BetterDisplay
# VirtualScreen the user never looks at and screenshots it by window-id.
#
# WHY it must be disconnected when idle: the virtual screen is placed adjacent to the
# main display, so while connected the cursor can slide off the shared edge into an
# invisible display and "vanish". Connect only for a visual batch; disconnect when done.

BD="/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay"
NAME="${TERMY_CAPTURE_SCREEN:-TermyCapture}"
# Generated-resolution seeds; BetterDisplay picks a sane HiDPI mode from these.
RES="${TERMY_CAPTURE_RES:-1920x1200,1480x940,2560x1440}"

if [[ ! -x "$BD" ]]; then
  echo "error: BetterDisplay not found at $BD (install from https://betterdisplay.pro)" >&2
  exit 1
fi

exists() { "$BD" get -identifiers 2>/dev/null | grep -q "\"name\" : \"$NAME\""; }

# Print the screencapture display index (-D N) for the virtual screen, or nothing.
display_index() {
  cat > /tmp/termy-capture-index.swift <<'SWIFT'
import AppKit
import CoreGraphics
let want = CommandLine.arguments.dropFirst().first ?? ""
let target = NSScreen.screens.first { $0.localizedName == want }
guard let target,
      let n = (target.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
else { exit(1) }
var ids = [CGDirectDisplayID](repeating: 0, count: 16)
var count: UInt32 = 0
CGGetActiveDisplayList(16, &ids, &count)
for i in 0..<Int(count) where ids[i] == n { print(i + 1); exit(0) }
exit(1)
SWIFT
  swift /tmp/termy-capture-index.swift "$NAME" 2>/dev/null || true
}

ensure_created() {
  if ! exists; then
    echo "Creating virtual screen '$NAME'…"
    "$BD" create -type=VirtualScreen -virtualScreenName="$NAME" -resolutionList="$RES" >/dev/null 2>&1 || true
    sleep 2
  fi
}

connect() {
  ensure_created
  "$BD" set -name="$NAME" -connected=on >/dev/null 2>&1 || true
  sleep 2
  echo "Virtual screen '$NAME' connected (capture -D index: $(display_index || echo '?'))."
}

disconnect() {
  "$BD" set -name="$NAME" -connected=off >/dev/null 2>&1 || true
  echo "Virtual screen '$NAME' disconnected (cursor can no longer wander into it)."
}

status() {
  if exists; then
    local idx; idx="$(display_index || true)"
    if [[ -n "$idx" ]]; then
      echo "'$NAME' exists and is CONNECTED (capture -D index $idx)."
    else
      echo "'$NAME' exists but is DISCONNECTED."
    fi
  else
    echo "'$NAME' does not exist yet (run: $0 connect)."
  fi
}

case "${1:-status}" in
  connect|on)       connect ;;
  disconnect|off)   disconnect ;;
  ensure)           ensure_created ;;
  index)            display_index ;;
  status)           status ;;
  *) echo "usage: $0 [connect|disconnect|ensure|index|status]" >&2; exit 2 ;;
esac
