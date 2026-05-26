#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Termy"
BUNDLE_ID="pl.kacper.Termy"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Resources/AppIcon.icns"

# Kill any prior instance of THIS bundle's binary by its exact path. `pkill -x
# "$APP_NAME"` could miss the running process, and since the launch below uses
# `open -n` (always spawns a new instance) that left a second copy alongside the
# old one — stale windows that mask the rebuild during visual gating.
pkill -f "$APP_BINARY" >/dev/null 2>&1 || true

# M5: FreeRDP is a vendored static C build (not a SwiftPM package). If the
# archives are absent — e.g. first-time clone, or after `git clean` — build
# them before `swift build`. The builder is idempotent (skips when PINS+stamp
# match), so a present-archive case is a sub-second no-op.
if [[ ! -d "$ROOT_DIR/vendor/freerdp/lib" ]]; then
  echo "=== M5: vendor/freerdp/lib absent — invoking script/build_freerdp.sh ==="
  "$ROOT_DIR/script/build_freerdp.sh"
fi

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"

# v3: stage bundled Geist fonts when present. ATSApplicationFontsPath (Info.plist)
# registers them at launch — zero network. If not yet vendored, the app falls
# back to SF (Typography.swift handles the missing-face case), so this never
# blocks the build.
if compgen -G "$ROOT_DIR/Resources/Fonts/*.otf" > /dev/null 2>&1; then
  rm -rf "$APP_RESOURCES/Fonts"
  cp -R "$ROOT_DIR/Resources/Fonts" "$APP_RESOURCES/Fonts"
else
  echo "warning: Resources/Fonts/*.otf not vendored — UI falls back to SF (see v3 substrate plan Task 3)" >&2
fi

# FB-1: stage the vendored zsh-syntax-highlighting into the app Resources so the
# integration .zshrc can source it via $TERMY_SYNTAX_HL_DIR (TermyStore sets the path
# to Bundle.main.resourceURL/zsh-syntax-highlighting).
if [[ ! -r "$ROOT_DIR/vendor/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  echo "error: vendor/zsh-syntax-highlighting missing — run FB-1 Task 1 vendoring" >&2
  exit 1
fi
rm -rf "$APP_RESOURCES/zsh-syntax-highlighting"
cp -R "$ROOT_DIR/vendor/zsh-syntax-highlighting" "$APP_RESOURCES/"

# FB-1 follow-up (spec-hl): stage the committed converted spec DB + the highlighter
if [[ ! -d "$ROOT_DIR/vendor/specs/out" ]]; then
  echo "error: vendor/specs/out missing — regenerate with script/convert-fig-specs.mjs" >&2
  exit 1
fi
rm -rf "$APP_RESOURCES/specs"
cp -R "$ROOT_DIR/vendor/specs/out" "$APP_RESOURCES/specs"
cp "$ROOT_DIR/script/shell/termy-spec-highlighter.zsh" "$APP_RESOURCES/specs/"

# FB-3-2: stage the agent state hook helper into Resources (must stay
# executable — TermyStore resolves it via Bundle.main.resourceURL and bakes its
# absolute path into the Claude Code `--settings` hook commands).
if [[ ! -r "$ROOT_DIR/script/shell/termy-agent-hook.sh" ]]; then
  echo "error: script/shell/termy-agent-hook.sh missing — run FB-3-2 Task 7" >&2
  exit 1
fi
cp "$ROOT_DIR/script/shell/termy-agent-hook.sh" "$APP_RESOURCES/termy-agent-hook.sh"
chmod +x "$APP_RESOURCES/termy-agent-hook.sh"

# M4: Sparkle is a binary dynamic framework — embed it, add the loader
# rpath, then ad-hoc re-sign (install_name_tool invalidates the signature
# on arm64; an unsigned/ad-hoc local .app must still carry a valid seal).
SPARKLE_FW="$(find "$(swift build --show-bin-path)" "$ROOT_DIR/.build/artifacts" -name Sparkle.framework -type d -print -quit 2>/dev/null || true)"
if [[ -z "$SPARKLE_FW" ]]; then
  echo "error: Sparkle.framework not found in build artifacts" >&2
  exit 1
fi
mkdir -p "$APP_CONTENTS/Frameworks"
rm -rf "$APP_CONTENTS/Frameworks/Sparkle.framework"
cp -R "$SPARKLE_FW" "$APP_CONTENTS/Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BINARY" 2>/dev/null || true
FW_VER_DIR="$(find "$APP_CONTENTS/Frameworks/Sparkle.framework/Versions" -mindepth 1 -maxdepth 1 -type d ! -name Current -print -quit)"
for HELPER in "XPCServices/Installer.xpc" "XPCServices/Downloader.xpc" "Autoupdate" "Updater.app"; do
  [[ -e "$FW_VER_DIR/$HELPER" ]] && codesign -f -s - "$FW_VER_DIR/$HELPER" >/dev/null 2>&1 || true
done
codesign -f -s - "$APP_CONTENTS/Frameworks/Sparkle.framework" >/dev/null 2>&1 || true

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSSupportsAutomaticTermination</key>
  <true/>
  <key>NSSupportsSuddenTermination</key>
  <true/>
  <key>ATSApplicationFontsPath</key>
  <string>Fonts</string>
</dict>
</plist>
PLIST

codesign -f -s - "$APP_BUNDLE" >/dev/null 2>&1 || true

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
