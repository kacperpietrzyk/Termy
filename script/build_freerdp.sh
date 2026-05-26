#!/usr/bin/env bash
# script/build_freerdp.sh — offline-reproducible, pinned, fails-closed FreeRDP static builder
#
# Builds FreeRDP 3.26.0 + OpenSSL 3.5.3 + zlib 1.3.1 as static archives into
# vendor/freerdp/{lib,include}. Sources are fetched once into a SHA-verified
# cache; the build runs offline (no network during cmake/make).
#
# Usage:
#   ./script/build_freerdp.sh          # build (idempotent: skips if stamp matches)
#   ./script/build_freerdp.sh --force  # rebuild unconditionally
#
# Prerequisites: cmake ≥3.13, make, clang, perl, git (all on PATH)
# Build time: 10–40 min on Apple Silicon M-series
#
# M5 Task 2 — pinned offline FreeRDP 3.26.0 static build + transitive audit

set -euo pipefail

# ---------------------------------------------------------------------------
# Pinned versions and SHAs (source of truth: vendor/freerdp/PINS)
# The verify loop below reads PINS; these constants mirror it exactly.
# Changing only one side causes the script to abort — fails closed by design.
# ---------------------------------------------------------------------------

FREERDP_TAG="3.26.0"
FREERDP_REPO="https://github.com/FreeRDP/FreeRDP"
FREERDP_PEELED_SHA="3f6d7cb1f8973cc84c66b258a9a61c4e2b2f30a6"

OPENSSL_TAG="openssl-3.5.3"
OPENSSL_REPO="https://github.com/openssl/openssl"
OPENSSL_PEELED_SHA="c4da9ac23de497ce039a102e6715381047899447"

ZLIB_TAG="v1.3.1"
ZLIB_REPO="https://github.com/madler/zlib"
ZLIB_PEELED_SHA="51b7f2abdade71cd9bb0e7a373ef2610ec6f9daf"

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PINS_FILE="$ROOT_DIR/vendor/freerdp/PINS"
CACHE_DIR="$ROOT_DIR/vendor/freerdp/.cache"
BUILD_DIR="$ROOT_DIR/vendor/freerdp/.build"
PREFIX="$ROOT_DIR/vendor/freerdp"
STAMP_FILE="$PREFIX/.build-stamp"
OVERLAYS_DIR="$ROOT_DIR/vendor/freerdp/overlays"

# ---------------------------------------------------------------------------
# Tool detection — fails closed if any required tool is absent
# ---------------------------------------------------------------------------

require_tool() {
    local tool="$1"
    if ! command -v "$tool" &>/dev/null; then
        echo "ERROR: required tool '$tool' not found on PATH." >&2
        echo "       Install it and retry. No build was attempted." >&2
        exit 1
    fi
}

require_tool git
require_tool make
require_tool perl
require_tool clang

# cmake: prefer PATH, then /opt/homebrew/bin (Apple Silicon Homebrew default)
if command -v cmake &>/dev/null; then
    CMAKE="$(command -v cmake)"
elif [[ -x /opt/homebrew/bin/cmake ]]; then
    CMAKE=/opt/homebrew/bin/cmake
else
    echo "ERROR: cmake not found on PATH or at /opt/homebrew/bin/cmake." >&2
    echo "       Install cmake ≥3.13 (e.g. brew install cmake) and retry." >&2
    exit 1
fi

# Verify cmake version ≥3.13
CMAKE_VERSION_FULL="$("$CMAKE" --version | head -1)"
CMAKE_MINOR="$("$CMAKE" --version | head -1 | sed 's/[^0-9]*\([0-9]*\)\.\([0-9]*\).*/\2/')"
CMAKE_MAJOR="$("$CMAKE" --version | head -1 | sed 's/[^0-9]*\([0-9]*\).*/\1/')"
if (( CMAKE_MAJOR < 3 )) || { (( CMAKE_MAJOR == 3 )) && (( CMAKE_MINOR < 13 )); }; then
    echo "ERROR: cmake ≥3.13 required; found $CMAKE_VERSION_FULL" >&2
    exit 1
fi

NCPU="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"

# ---------------------------------------------------------------------------
# Verify PINS file exists and contains the expected 3.26.0 entry (fails closed)
# ---------------------------------------------------------------------------

if [[ ! -f "$PINS_FILE" ]]; then
    echo "ERROR: vendor/freerdp/PINS not found at $PINS_FILE" >&2
    echo "       This file is checked in; if it is missing, the repository is corrupt." >&2
    exit 1
fi

verify_pins_entry() {
    local dep="$1" tag="$2" peeled_sha="$3"
    local pins_tag pins_sha
    pins_tag="$(grep "^TAG      $dep" "$PINS_FILE" | awk '{print $3}')"
    pins_sha="$(grep "^COMMIT   $dep" "$PINS_FILE" | awk '{print $3}')"
    if [[ "$pins_tag" != "$tag" ]]; then
        echo "ERROR: PINS mismatch for $dep: expected TAG=$tag but PINS says TAG=$pins_tag" >&2
        exit 1
    fi
    if [[ "$pins_sha" != "$peeled_sha" ]]; then
        echo "ERROR: PINS mismatch for $dep: expected COMMIT=$peeled_sha but PINS says COMMIT=$pins_sha" >&2
        exit 1
    fi
}

verify_pins_entry FREERDP "$FREERDP_TAG" "$FREERDP_PEELED_SHA"
verify_pins_entry OPENSSL  "$OPENSSL_TAG"  "$OPENSSL_PEELED_SHA"
verify_pins_entry ZLIB     "$ZLIB_TAG"     "$ZLIB_PEELED_SHA"

echo "PINS verification passed."

# ---------------------------------------------------------------------------
# Idempotency: compute a stamp from PINS + any existing archives
# Skip rebuild if stamp matches and --force is not given
# ---------------------------------------------------------------------------

FORCE="${1:-}"
if [[ -n "$FORCE" && "$FORCE" != "--force" ]]; then
    echo "ERROR: unknown argument '$FORCE'. Valid options: --force" >&2
    exit 1
fi

compute_stamp() {
    # Hash PINS + the modification timestamps of all .a files (if any)
    {
        cat "$PINS_FILE"
        find "$PREFIX/lib" -name '*.a' -exec stat -f '%N %m' {} \; 2>/dev/null || true
    } | shasum -a 256 | awk '{print $1}'
}

# NOTE: the stamp detects missing archives (hash changes) but NOT corrupt archives
# (same name/mtime, different content). Use --force if archives may be corrupt.
if [[ "$FORCE" != "--force" ]] && [[ -f "$STAMP_FILE" ]]; then
    current_stamp="$(compute_stamp)"
    recorded_stamp="$(cat "$STAMP_FILE")"
    if [[ "$current_stamp" == "$recorded_stamp" ]] && \
       ls "$PREFIX/lib/"*.a &>/dev/null 2>&1; then
        echo "Build is up-to-date (stamp matches PINS + archives). Skipping rebuild."
        echo "Use --force to rebuild unconditionally."
        exit 0
    fi
fi

# ---------------------------------------------------------------------------
# Fetch sources into SHA-verified cache (once; network only during clone/fetch)
# After this section the build runs offline.
# ---------------------------------------------------------------------------

mkdir -p "$CACHE_DIR" "$BUILD_DIR"

clone_and_verify() {
    local name="$1" repo="$2" tag="$3" expected_peeled_sha="$4"
    local cache_path="$CACHE_DIR/$name"

    if [[ -d "$cache_path/.git" ]]; then
        echo "[$name] Cache exists at $cache_path — verifying SHA..."
    else
        echo "[$name] Cloning $repo (tag $tag)..."
        git clone --filter=blob:none --no-checkout "$repo" "$cache_path"
    fi

    # Fetch the tag (idempotent; fast if already present)
    git -C "$cache_path" fetch --no-tags origin "refs/tags/$tag:refs/tags/$tag" 2>/dev/null || \
        git -C "$cache_path" fetch --no-tags origin tag "$tag"

    # Checkout the tag
    git -C "$cache_path" checkout --force "$tag"

    # Verify peeled commit SHA — ABORT on mismatch (fails-closed supply-chain check)
    local actual_peeled_sha
    actual_peeled_sha="$(git -C "$cache_path" rev-parse "${tag}^{commit}")"
    if [[ "$actual_peeled_sha" != "$expected_peeled_sha" ]]; then
        echo "ERROR: SHA mismatch for $name tag $tag!" >&2
        echo "       expected peeled commit: $expected_peeled_sha" >&2
        echo "       actual   peeled commit: $actual_peeled_sha" >&2
        echo "       Refusing to build. Check the PINS file and repository integrity." >&2
        exit 1
    fi
    echo "[$name] SHA verified: $actual_peeled_sha ✓"
}

clone_and_verify freerdp "$FREERDP_REPO" "$FREERDP_TAG" "$FREERDP_PEELED_SHA"
clone_and_verify openssl  "$OPENSSL_REPO"  "$OPENSSL_TAG"  "$OPENSSL_PEELED_SHA"
clone_and_verify zlib     "$ZLIB_REPO"     "$ZLIB_TAG"     "$ZLIB_PEELED_SHA"

# All source material is now in cache — build phase is fully offline from here.
echo ""
echo "=== All sources fetched and SHA-verified. Building offline (no network). ==="
echo ""

# ---------------------------------------------------------------------------
# Build 1: zlib (static, no shared) — install into PREFIX
# ---------------------------------------------------------------------------

echo "=== Building zlib $ZLIB_TAG ==="
ZLIB_BUILD="$BUILD_DIR/zlib"
rm -rf "$ZLIB_BUILD"
cp -R "$CACHE_DIR/zlib" "$ZLIB_BUILD"

"$CMAKE" -S "$ZLIB_BUILD" -B "$ZLIB_BUILD/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DBUILD_SHARED_LIBS=OFF

"$CMAKE" --build "$ZLIB_BUILD/build" --config Release -j "$NCPU"
"$CMAKE" --install "$ZLIB_BUILD/build"

# Remove any dynamic zlib artefacts (belt-and-suspenders)
find "$PREFIX/lib" -name 'libz.dylib' -o -name 'libz.*.dylib' 2>/dev/null | xargs rm -f || true
echo "=== zlib build complete ==="

# ---------------------------------------------------------------------------
# Build 2: OpenSSL (static, no-shared) — install into PREFIX
# ---------------------------------------------------------------------------

echo "=== Building OpenSSL $OPENSSL_TAG ==="
OPENSSL_BUILD="$BUILD_DIR/openssl"
rm -rf "$OPENSSL_BUILD"
cp -R "$CACHE_DIR/openssl" "$OPENSSL_BUILD"

(
    cd "$OPENSSL_BUILD"
    # darwin64-arm64-cc: Apple Silicon, 64-bit, Clang
    # no-shared: static libs only
    # no-tests no-docs no-apps: minimise build surface
    # no-engine no-fips: disable legacy engine API and FIPS module (not needed)
    perl Configure darwin64-arm64-cc \
        no-shared no-tests no-docs no-apps no-engine no-fips \
        -mmacosx-version-min=14.0 \
        --prefix="$PREFIX" \
        --libdir=lib

    make -j "$NCPU"
    make install_sw   # installs lib + include only, skips man pages
)

# Remove any dynamic OpenSSL artefacts
find "$PREFIX/lib" -name 'libssl*.dylib' -o -name 'libcrypto*.dylib' 2>/dev/null | xargs rm -f || true
echo "=== OpenSSL build complete ==="

# ---------------------------------------------------------------------------
# M5 Task 5 overlay hook:
#
# Before invoking cmake for FreeRDP, check for the custom rdpsnd subsystem
# overlay in vendor/freerdp/overlays/. The overlay is a *source-tree mirror*:
# files under it are copied, preserving their relative paths, into the
# FreeRDP build source tree, and an optional unified patch for the rdpsnd
# parent CMakeLists is applied. The rebuilt archives are gitignored; the
# overlay sources + patch are tracked.
#
# Task 5 layout (the real FreeRDP 3.26.0 add_channel_client_subsystem macro
# does `add_subdirectory(${_subsystem})`, so the subsystem MUST be its own
# directory — the original Task-2 flat `cp *.c` assumption did not match the
# 3.26.0 macro shape and is replaced here by a structure-preserving mirror):
#
#   overlays/channels/rdpsnd/client/termy/rdpsnd_termy.c   (the PCM subsystem)
#   overlays/channels/rdpsnd/client/termy/CMakeLists.txt   (its build file)
#   overlays/rdpsnd_client.cmake.patch                     (registers "termy"
#       in channels/rdpsnd/client/CMakeLists.txt via add_channel_client_subsystem)
#
# When the overlay is applied the build switches to WITH_MACAUDIO=OFF so the
# native CoreAudio "mac" subsystem (upstream #6882) is not compiled in and
# "termy" is the audio sink. Until Task 5 runs, the overlays directory is
# absent/empty, the hook is a no-op, and the build stays WITH_MACAUDIO=ON
# (the documented fallback).
# ---------------------------------------------------------------------------

FREERDP_SRC="$BUILD_DIR/freerdp"
rm -rf "$FREERDP_SRC"
cp -R "$CACHE_DIR/freerdp" "$FREERDP_SRC"

OVERLAY_APPLIED=false
# The overlay is "present" iff it carries the custom subsystem source. The
# find is anchored on the known filename so a stray file can't trigger it.
if [[ -d "$OVERLAYS_DIR" ]] && \
   find "$OVERLAYS_DIR" -type f -name 'rdpsnd_termy.c' -print -quit | grep -q .; then
    echo "=== M5 Task 5 overlay hook: mirroring custom rdpsnd subsystem into source tree ==="
    # Structure-preserving copy: every file under overlays/ EXCEPT the
    # top-level patch is mirrored into the FreeRDP source tree at the same
    # relative path (overlays/channels/... → $FREERDP_SRC/channels/...).
    while IFS= read -r -d '' src; do
        rel="${src#"$OVERLAYS_DIR"/}"
        [[ "$rel" == *.patch ]] && continue
        dest="$FREERDP_SRC/$rel"
        mkdir -p "$(dirname "$dest")"
        echo "    overlays/$rel → $rel"
        cp "$src" "$dest"
    done < <(find "$OVERLAYS_DIR" -type f -print0)

    # Apply the CMakeLists patch that registers the "termy" subsystem.
    # Fail closed: a non-applying patch must abort the build, not silently
    # produce an archive without the custom subsystem.
    if [[ -f "$OVERLAYS_DIR/rdpsnd_client.cmake.patch" ]]; then
        echo "    Applying rdpsnd_client.cmake.patch..."
        if ! patch -p1 -d "$FREERDP_SRC" < "$OVERLAYS_DIR/rdpsnd_client.cmake.patch"; then
            echo "ERROR: rdpsnd_client.cmake.patch failed to apply cleanly." >&2
            echo "       The pinned FreeRDP source may have changed; refresh the patch." >&2
            exit 1
        fi
    else
        echo "ERROR: overlay present but rdpsnd_client.cmake.patch missing." >&2
        echo "       The subsystem source would not be registered. Aborting." >&2
        exit 1
    fi
    OVERLAY_APPLIED=true
    echo "=== Task 5 overlay applied. Custom 'termy' rdpsnd subsystem will be compiled in. ==="
fi

# WITH_MACAUDIO is ON only when the custom subsystem is NOT present (fallback).
if [[ "$OVERLAY_APPLIED" == "true" ]]; then
    MACAUDIO_FLAG=OFF
    echo "=== Audio sink: vendored 'termy' PCM subsystem (WITH_MACAUDIO=OFF). ==="
else
    MACAUDIO_FLAG=ON
    echo "=== No Task 5 overlay present. Building WITH_MACAUDIO=ON (fallback). ==="
fi

# ---------------------------------------------------------------------------
# Build 3: FreeRDP 3.26.0 (static, minimal channels, Release)
# ---------------------------------------------------------------------------

echo "=== Building FreeRDP $FREERDP_TAG ==="

"$CMAKE" -S "$FREERDP_SRC" -B "$FREERDP_SRC/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    \
    -DOPENSSL_ROOT_DIR="$PREFIX" \
    -DOPENSSL_USE_STATIC_LIBS=ON \
    -DZLIB_ROOT="$PREFIX" \
    \
    -DBUILD_SHARED_LIBS=OFF \
    -DWITH_SERVER=OFF \
    -DWITH_SAMPLE=OFF \
    -DWITH_CLIENT_SDL2=OFF \
    -DWITH_CLIENT_SDL3=OFF \
    -DWITH_X11=OFF \
    -DWITH_WAYLAND=OFF \
    -DWITH_KRB5=OFF \
    -DWITH_WEBVIEW=OFF \
    -DWITH_FFMPEG=OFF \
    -DWITH_SWSCALE=OFF \
    -DWITH_OPUS=OFF \
    -DWITH_OPENH264=OFF \
    -DWITH_FAAC=OFF \
    -DWITH_FAAD=OFF \
    -DWITH_LAME=OFF \
    -DWITH_FDK_AAC=OFF \
    -DWITH_CJSON=OFF \
    -DWITH_AAD=OFF \
    -DWITH_PCSC=OFF \
    -DWITH_CUPS=OFF \
    \
    `# ── spec §1 channel allowlist ─────────────────────────────────────` \
    `# Design spec §1 invariant: build ONLY core + the cliprdr / rdpdr /` \
    `# rdpsnd channels + the gdi software framebuffer. CHANNEL_DRIVE stays` \
    `# ON because spec §1's RDP scope is clipboard + FOLDER-DRIVE +` \
    `# audio-out, and folder redirection is an rdpdr device-type addin —` \
    `# without it FreeRDP_RedirectDrives has no drive device to load.` \
    `# Every other channel FreeRDP 3.26.0 builds client-side by default is` \
    `# disabled here (audited against channels/*/ChannelOptions.cmake).` \
    `# CHANNEL_AUDIN=OFF is non-negotiable (PRD: no microphone; M5 audio` \
    `# is output-only). Mirrors the existing CHANNEL_URBDRC=OFF discipline.` \
    -DCHANNEL_URBDRC=OFF \
    -DCHANNEL_AINPUT=OFF \
    -DCHANNEL_AUDIN=OFF \
    -DCHANNEL_DISP=OFF \
    -DCHANNEL_DRDYNVC=OFF \
    -DCHANNEL_ECHO=OFF \
    -DCHANNEL_ENCOMSP=OFF \
    -DCHANNEL_GEOMETRY=OFF \
    -DCHANNEL_GFXREDIR=OFF \
    -DCHANNEL_LOCATION=OFF \
    -DCHANNEL_PARALLEL=OFF \
    -DCHANNEL_PRINTER=OFF \
    -DCHANNEL_RAIL=OFF \
    -DCHANNEL_RDP2TCP=OFF \
    -DCHANNEL_RDPEAR=OFF \
    -DCHANNEL_RDPECAM=OFF \
    -DCHANNEL_RDPEI=OFF \
    -DCHANNEL_RDPEMSC=OFF \
    -DCHANNEL_RDPEWA=OFF \
    -DCHANNEL_RDPGFX=OFF \
    -DCHANNEL_REMDESK=OFF \
    -DCHANNEL_SERIAL=OFF \
    -DCHANNEL_SMARTCARD=OFF \
    -DCHANNEL_SSHAGENT=OFF \
    -DCHANNEL_TELEMETRY=OFF \
    -DCHANNEL_TSMF=OFF \
    -DCHANNEL_VIDEO=OFF \
    `# ── end spec §1 channel allowlist ─────────────────────────────────` \
    \
    -DWITH_MANPAGES=OFF \
    -DWITH_INTERNAL_RC4=ON \
    -DWITH_INTERNAL_MD4=ON \
    -DWITH_INTERNAL_MD5=ON \
    -DWITH_MACAUDIO="$MACAUDIO_FLAG"

"$CMAKE" --build "$FREERDP_SRC/build" --config Release -j "$NCPU"
"$CMAKE" --install "$FREERDP_SRC/build"

# Remove any dynamic FreeRDP artefacts (belt-and-suspenders for static-only)
find "$PREFIX/lib" -name '*.dylib' 2>/dev/null | xargs rm -f || true
echo "=== FreeRDP build complete ==="

# ---------------------------------------------------------------------------
# Post-build verification: confirm key static archives are present
# ---------------------------------------------------------------------------

echo ""
echo "=== Post-build verification ==="
REQUIRED_ARCHIVES=(
    "libfreerdp3.a"
    "libwinpr3.a"
    "libssl.a"
    "libcrypto.a"
    "libz.a"
)

all_ok=true
for arc in "${REQUIRED_ARCHIVES[@]}"; do
    if [[ -f "$PREFIX/lib/$arc" ]]; then
        size="$(du -sh "$PREFIX/lib/$arc" | cut -f1)"
        echo "  ✓  $arc ($size)"
    else
        echo "  ✗  MISSING: $arc" >&2
        all_ok=false
    fi
done

if [[ "$all_ok" != "true" ]]; then
    echo "ERROR: one or more required static archives are missing. Build is incomplete." >&2
    exit 1
fi

# Verify no dylibs slipped in alongside the static archives
dylib_count="$(find "$PREFIX/lib" -name '*.dylib' 2>/dev/null | wc -l | tr -d ' ')"
if (( dylib_count > 0 )); then
    echo "WARNING: $dylib_count .dylib file(s) found in $PREFIX/lib — check for dynamic linkage:" >&2
    find "$PREFIX/lib" -name '*.dylib' >&2
fi

# Sanity-check that the FreeRDP archive is actually linked against our OpenSSL
# (nm returns non-zero if symbols absent; we just warn, don't abort)
if nm "$PREFIX/lib/libfreerdp3.a" 2>/dev/null | grep -q "SSL_"; then
    echo "  ✓  libfreerdp3.a contains SSL_ symbols (OpenSSL linkage confirmed)"
else
    echo "  ?  SSL_ symbols not found in libfreerdp3.a (may be in libfreerdp-client3.a)"
fi

echo ""
echo "=== All required static archives present ==="
echo ""
echo "Installed archives:"
ls -lh "$PREFIX/lib/"*.a 2>/dev/null || true
echo ""
echo "Include layout (top level):"
ls "$PREFIX/include/" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Write idempotency stamp (compute_stamp defined once, near the top)
# ---------------------------------------------------------------------------
compute_stamp > "$STAMP_FILE"
echo ""
echo "Build stamp written to $STAMP_FILE"
echo ""
echo "=== build_freerdp.sh complete ==="
