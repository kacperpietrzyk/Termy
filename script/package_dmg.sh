#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Termy"
BUNDLE_ID="pl.kacper.Termy"
MIN_SYSTEM_VERSION="14.0"
VERSION="${VERSION:-0.1.0}"
IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
UPDATE_BASE_URL="${UPDATE_BASE_URL:-}"
RELEASE_NOTES="${RELEASE_NOTES:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
DISTRIBUTION_AUDIT_PATH="$DIST_DIR/$APP_NAME-$VERSION.distribution.json"
ENTITLEMENTS="$ROOT_DIR/Termy.entitlements"
APP_ICON="$ROOT_DIR/Resources/AppIcon.icns"
APP_SIGNED_WITH_DEVELOPER_ID=false
HARDENED_RUNTIME_ENABLED=false
DMG_NOTARIZED_AND_STAPLED=false
APP_SANDBOX_ENABLED=false
SPARKLE_NESTED_HELPERS_SIGNED=false
APPCAST_EMITTED=false

swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE" "$DMG_PATH" "$DISTRIBUTION_AUDIT_PATH" "$DIST_DIR/appcast.xml"
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

# M5: FreeRDP is STATIC (unlike Sparkle's dynamic framework) — no embed/rpath/nested-sign.
# The Sparkle block below remains because Sparkle is a dynamic .framework; do
# not reintroduce M4-style Frameworks/embed + install_name_tool + nested-helper
# inside-out signing for FreeRDP (linker pulls libfreerdp3.a etc. directly into
# the Termy executable, like SwiftTerm — the bundle's single codesign covers it).

# M4: embed Sparkle.framework + loader rpath. Inside-out Developer ID
# signing of the nested helpers is done in the codesign block below
# (added by M4 Task 6); here we only stage the framework into the bundle.
SPARKLE_FW="$(find "$(swift build -c release --show-bin-path)" "$ROOT_DIR/.build/artifacts" -name Sparkle.framework -type d -print -quit 2>/dev/null || true)"
if [[ -z "$SPARKLE_FW" ]]; then
  echo "error: Sparkle.framework not found in release build artifacts" >&2
  exit 1
fi
mkdir -p "$APP_CONTENTS/Frameworks"
rm -rf "$APP_CONTENTS/Frameworks/Sparkle.framework"
cp -R "$SPARKLE_FW" "$APP_CONTENTS/Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BINARY" 2>/dev/null || true

/usr/libexec/PlistBuddy -c "Clear dict" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $APP_NAME" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string $APP_NAME" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string $MIN_SYSTEM_VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :NSPrincipalClass string NSApplication" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :ATSApplicationFontsPath string Fonts" "$INFO_PLIST"

# M4: Sparkle config. SUFeedURL only when an update base URL is given;
# privacy keys always (no telemetry / no first-run prompt / checks off).
/usr/libexec/PlistBuddy -c "Add :SUEnableSystemProfiling bool false" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool false" "$INFO_PLIST"
if [[ -n "$UPDATE_BASE_URL" ]]; then
  /usr/libexec/PlistBuddy -c "Add :SUFeedURL string ${UPDATE_BASE_URL%/}/appcast.xml" "$INFO_PLIST"
fi
if [[ -n "${SPARKLE_PUBLIC_ED_KEY:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string ${SPARKLE_PUBLIC_ED_KEY}" "$INFO_PLIST"
fi

if [[ -n "$IDENTITY" ]]; then
  FW_VER_DIR="$(find "$APP_CONTENTS/Frameworks/Sparkle.framework/Versions" -mindepth 1 -maxdepth 1 -type d ! -name Current -print -quit)"
  [[ -n "$FW_VER_DIR" ]] || { echo "error: Sparkle.framework versioned dir not found" >&2; exit 1; }
  # English-only UI (PRD) + lean (P3): strip non-en localizations before signing.
  find "$APP_CONTENTS/Frameworks/Sparkle.framework" -name '*.lproj' ! -name 'en.lproj' -exec rm -rf {} + 2>/dev/null || true
  codesign -f -s "$IDENTITY" -o runtime "$FW_VER_DIR/XPCServices/Installer.xpc"
  codesign -f -s "$IDENTITY" -o runtime --preserve-metadata=entitlements "$FW_VER_DIR/XPCServices/Downloader.xpc"
  codesign -f -s "$IDENTITY" -o runtime "$FW_VER_DIR/Autoupdate"
  codesign -f -s "$IDENTITY" -o runtime "$FW_VER_DIR/Updater.app"
  codesign -f -s "$IDENTITY" -o runtime "$APP_CONTENTS/Frameworks/Sparkle.framework"
  SPARKLE_NESTED_HELPERS_SIGNED=true
  codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP_BUNDLE"
  SIGNING_DETAILS="$(codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1 || true)"
  if [[ "$SIGNING_DETAILS" == *"Authority=Developer ID Application"* ]]; then
    APP_SIGNED_WITH_DEVELOPER_ID=true
  fi
  if [[ "$SIGNING_DETAILS" == *"runtime"* ]]; then
    HARDENED_RUNTIME_ENABLED=true
  fi
  ENTITLEMENT_DETAILS="$(codesign -d --entitlements :- "$APP_BUNDLE" 2>/dev/null || true)"
  if [[ "$ENTITLEMENT_DETAILS" == *"com.apple.security.app-sandbox"* && "$ENTITLEMENT_DETAILS" == *"<true/>"* ]]; then
    APP_SANDBOX_ENABLED=true
  fi
else
  echo "warning: DEVELOPER_ID_APPLICATION is not set; creating unsigned DMG" >&2
fi

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$APP_BUNDLE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  if xcrun stapler validate "$DMG_PATH" >/dev/null 2>&1; then
    DMG_NOTARIZED_AND_STAPLED=true
  fi
else
  echo "warning: NOTARY_PROFILE is not set; skipping notarization" >&2
fi

APPCAST_PATH="$DIST_DIR/appcast.xml"
if [[ -n "$UPDATE_BASE_URL" ]]; then
  if [[ "$UPDATE_BASE_URL" != https://* ]]; then
    echo "error: UPDATE_BASE_URL must use https" >&2
    exit 1
  fi
  SIGN_UPDATE="${SPARKLE_BIN:-}/sign_update"
  if [[ ! -x "$SIGN_UPDATE" ]]; then
    SIGN_UPDATE="$(find "$ROOT_DIR/.build" -name sign_update -type f -perm -u+x -print -quit 2>/dev/null || true)"
  fi
  if [[ -z "$SIGN_UPDATE" || ! -x "$SIGN_UPDATE" ]]; then
    echo "error: Sparkle sign_update tool not found (set SPARKLE_BIN to Sparkle's bin dir)" >&2
    exit 1
  fi
  SIG_LINE="$("$SIGN_UPDATE" "$DMG_PATH")"
  DMG_URL="${UPDATE_BASE_URL%/}/$APP_NAME-$VERSION.dmg"
  PUBDATE="$(LC_TIME=C date -u +"%a, %d %b %Y %H:%M:%S +0000")"
  NOTES_BLOCK=""
  if [[ -n "$RELEASE_NOTES" ]]; then
    NOTES_BLOCK="<description><![CDATA[${RELEASE_NOTES}]]></description>"
  fi
  cat > "$APPCAST_PATH" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>$APP_NAME</title>
    <item>
      <title>$VERSION</title>
      ${NOTES_BLOCK}
      <pubDate>$PUBDATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_SYSTEM_VERSION</sparkle:minimumSystemVersion>
      <enclosure url="$DMG_URL" type="application/octet-stream" $SIG_LINE />
    </item>
  </channel>
</rss>
XML
  APPCAST_EMITTED=true
  echo "$APPCAST_PATH"
fi

MISSING_REQUIREMENTS=()
if [[ "$APP_SIGNED_WITH_DEVELOPER_ID" != true ]]; then
  MISSING_REQUIREMENTS+=("\"developerIDApplicationSignature\"")
fi
if [[ "$HARDENED_RUNTIME_ENABLED" != true ]]; then
  MISSING_REQUIREMENTS+=("\"hardenedRuntime\"")
fi
if [[ "$DMG_NOTARIZED_AND_STAPLED" != true ]]; then
  MISSING_REQUIREMENTS+=("\"notarizedAndStapledDMG\"")
fi
if [[ "$APP_SANDBOX_ENABLED" == true ]]; then
  MISSING_REQUIREMENTS+=("\"appSandboxDisabled\"")
fi
# M5 distribution-audit fields:
# • freerdpStaticLinked is constitutional: FreeRDP is always statically linked
#   in this milestone's build (no dynamic-framework path exists).
# • freerdpVersion is derived from vendor/freerdp/PINS at packaging time — the
#   audit JSON cannot drift from the build pin. Same grep|awk idiom as
#   build_freerdp.sh; fail-closed if PINS is missing/malformed.
# • rdpTransitiveAudited is true iff the policy doc THIRDPARTY-RDP.md is
#   present at repo root.
FREERDP_STATIC_LINKED=true
FREERDP_VERSION="$(grep '^TAG[[:space:]]*FREERDP' "$ROOT_DIR/vendor/freerdp/PINS" | awk '{print $3}')"
if [[ -z "$FREERDP_VERSION" ]]; then
  echo "error: PINS missing FREERDP TAG entry" >&2
  exit 1
fi
# RDP_ prefix (not FREERDP_): the field covers all RDP transitive deps (OpenSSL, zlib), not just FreeRDP itself.
if [[ -f "$ROOT_DIR/THIRDPARTY-RDP.md" ]]; then
  RDP_TRANSITIVE_AUDITED=true
else
  RDP_TRANSITIVE_AUDITED=false
fi
# FB-1 follow-up (spec-hl): true iff the policy doc THIRDPARTY-SPECS.md is present at repo root.
if [[ -f "$ROOT_DIR/THIRDPARTY-SPECS.md" ]]; then
  SPECS_AUDITED=true
else
  SPECS_AUDITED=false
fi

MISSING_JSON="$(IFS=,; echo "${MISSING_REQUIREMENTS[*]}")"
cat > "$DISTRIBUTION_AUDIT_PATH" <<EOF
{
  "appBundleSignedWithDeveloperID": $APP_SIGNED_WITH_DEVELOPER_ID,
  "hardenedRuntimeEnabled": $HARDENED_RUNTIME_ENABLED,
  "dmgNotarizedAndStapled": $DMG_NOTARIZED_AND_STAPLED,
  "appSandboxEnabled": $APP_SANDBOX_ENABLED,
  "satisfiesDirectDistributionPRD": $([[ ${#MISSING_REQUIREMENTS[@]} -eq 0 ]] && echo true || echo false),
  "sparkleNestedHelpersSigned": $SPARKLE_NESTED_HELPERS_SIGNED,
  "appcastEmitted": $APPCAST_EMITTED,
  "freerdpStaticLinked": $FREERDP_STATIC_LINKED,
  "freerdpVersion": "$FREERDP_VERSION",
  "rdpTransitiveAudited": $RDP_TRANSITIVE_AUDITED,
  "specsAudited": $SPECS_AUDITED,
  "missingRequirements": [$MISSING_JSON]
}
EOF
echo "$DISTRIBUTION_AUDIT_PATH"

echo "$DMG_PATH"
