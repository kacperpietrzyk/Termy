#!/usr/bin/env bash
set -euo pipefail

# Agent-executable release runbook for Termy. Builds a signed+notarized DMG via
# package_dmg.sh, REFUSES to publish anything that fails the PRD distribution
# audit, then uploads the DMG to GitHub Releases and the EdDSA-signed appcast to
# the gh-pages feed. All keys stay in the Mac Keychain — nothing here reads a
# GitHub Secret. See docs/RELEASING.md.

usage() { echo "usage: $0 vX.Y.Z" >&2; exit 2; }

RAW_VERSION="${1:-}"
[[ -n "$RAW_VERSION" ]] || usage
VERSION="${RAW_VERSION#v}"                       # accept v0.2.0 or 0.2.0
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must be semver (e.g. v0.2.0); got '$RAW_VERSION'" >&2
  exit 2
fi
TAG="v$VERSION"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Termy"

# ---- config (override via env) ----
GITHUB_REPO="${GITHUB_REPO:-kacperpietrzyk/Termy}"
UPDATE_FEED_URL="${UPDATE_FEED_URL:-https://kacperpietrzyk.github.io/Termy/appcast.xml}"
NOTARY_PROFILE="${NOTARY_PROFILE:-TermyNotary}"
PAGES_BRANCH="${PAGES_BRANCH:-gh-pages}"
# DEVELOPER_ID_APPLICATION and SPARKLE_PUBLIC_ED_KEY must come from the env
# (the EdDSA public key is pinned here once generated — see docs/RELEASING.md).

# ---- preflight: fail fast, before any build, if a credential is missing ----
fail() { echo "preflight: $1" >&2; exit 1; }

[[ -n "${DEVELOPER_ID_APPLICATION:-}" ]] || \
  fail "DEVELOPER_ID_APPLICATION unset (the Developer ID Application identity name)"
security find-identity -v -p codesigning | grep -qF "$DEVELOPER_ID_APPLICATION" || \
  fail "Developer ID identity '$DEVELOPER_ID_APPLICATION' not found in the keychain"
[[ -n "${SPARKLE_PUBLIC_ED_KEY:-}" ]] || \
  fail "SPARKLE_PUBLIC_ED_KEY unset (generate_keys first; see docs/RELEASING.md)"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 || \
  fail "notarytool profile '$NOTARY_PROFILE' missing (xcrun notarytool store-credentials)"
command -v gh >/dev/null 2>&1 || fail "gh CLI not installed"
gh auth status >/dev/null 2>&1 || fail "gh not authenticated (gh auth login)"

echo "== preflight OK; building $TAG =="

# ---- build, sign, notarize, emit appcast (package_dmg.sh enforces it all) ----
VERSION="$VERSION" \
DEVELOPER_ID_APPLICATION="$DEVELOPER_ID_APPLICATION" \
NOTARY_PROFILE="$NOTARY_PROFILE" \
UPDATE_FEED_URL="$UPDATE_FEED_URL" \
SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY" \
GITHUB_REPO="$GITHUB_REPO" \
  "$ROOT_DIR/script/package_dmg.sh"

DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
APPCAST_PATH="$DIST_DIR/appcast.xml"
AUDIT_PATH="$DIST_DIR/$APP_NAME-$VERSION.distribution.json"

# ---- self-enforcing publication gate ----
# Refuse to publish unless the build satisfies the PRD direct-distribution
# requirements (Developer-ID signed + hardened runtime + notarized/stapled +
# App Sandbox OFF). This is the rule the agent cannot skip.
[[ -f "$AUDIT_PATH" ]] || { echo "error: audit $AUDIT_PATH not produced" >&2; exit 1; }
if ! grep -q '"satisfiesDirectDistributionPRD": true' "$AUDIT_PATH"; then
  echo "REFUSING TO PUBLISH: $AUDIT_PATH reports satisfiesDirectDistributionPRD=false" >&2
  cat "$AUDIT_PATH" >&2
  exit 1
fi
[[ -f "$DMG_PATH" && -f "$APPCAST_PATH" ]] || { echo "error: DMG or appcast missing" >&2; exit 1; }

# ---- publish DMG to GitHub Releases ----
# NOTE: the DMG is published BEFORE the feed so the appcast's enclosure URL is
# downloadable the moment the feed goes live. If the feed push below fails after
# this succeeds, the Release exists with a stale feed and a re-run is blocked by
# the existing tag. Recover with:
#   gh release delete "$TAG" --repo "$GITHUB_REPO" --yes && git worktree prune
# then re-run this script.
echo "== publishing $TAG to GitHub Releases =="
gh release create "$TAG" "$DMG_PATH" \
  --repo "$GITHUB_REPO" \
  --title "$TAG" \
  --notes "${RELEASE_NOTES:-Termy $TAG}"

# ---- update the appcast feed on the Pages branch (isolated worktree) ----
echo "== updating $PAGES_BRANCH feed =="
PAGES_WT="$(mktemp -d)"
# Prune the worktree registration on any exit so a partial-failure run does not
# leak an accumulating stale worktree (the happy path removes it explicitly below).
trap 'git -C "$ROOT_DIR" worktree prune 2>/dev/null || true' EXIT
git -C "$ROOT_DIR" worktree add "$PAGES_WT" "$PAGES_BRANCH"
cp "$APPCAST_PATH" "$PAGES_WT/appcast.xml"
git -C "$PAGES_WT" add appcast.xml
git -C "$PAGES_WT" commit -m "release: appcast for $TAG"
git -C "$PAGES_WT" push origin "$PAGES_BRANCH"
git -C "$ROOT_DIR" worktree remove "$PAGES_WT"

echo "== done: $TAG published =="
