# Contributing to Termy

Thanks for your interest! Termy is a native macOS app (SwiftPM). The **product** is a
single-user, privacy-absolute tool; the **project** is open to contributors. Please keep
changes aligned with the principles in [`ROADMAP.md`](./ROADMAP.md) (privacy, keyboard-first,
light & fast, native macOS, macOS-only/single-user).

## Building & testing

**Prerequisites:** macOS (Apple Silicon), Xcode toolchain, and `cmake` ≥ 3.13 (`brew install cmake`).

```bash
./script/build_freerdp.sh   # once: pinned static FreeRDP (10–40 min, then cached)
swift build
swift test
```

`vendor/freerdp/{include,lib,bin,share}` are build outputs, not committed — the script
generates them. Run `swift test` directly (not piped) so its exit code isn't masked.

## Contributor vs maintainer

You can build, test, and run an **unsigned** local build with just the above. The
following are **maintainer-only** and not required to contribute:

- Signed + notarized DMG releases (Apple Developer account, Developer ID certificate,
  notary profile).
- Sparkle auto-update signing (the EdDSA key; lives in the maintainer's Keychain).
- iCloud sync (bound to the maintainer's iCloud container `iCloud.pl.kacper.Termy`).

## Trying a build (testers)

Until automated releases exist, the easiest path is to build from source (above). For a
ready-to-run app, the maintainer attaches a signed, notarized DMG to a
[GitHub Release](../../releases) when one is published; that is the recommended path for
testers without a build environment.

## Pull requests

1. Branch from `main`, keep changes surgical and matching existing patterns.
2. Add/adjust tests; ensure `swift build` is warning-free and `swift test` passes.
3. Open a PR; CI must pass; one review is required.

## Developer Certificate of Origin (DCO)

All commits must be signed off, certifying the [DCO](https://developercertificate.org/).
Add a sign-off with `-s`:

```bash
git commit -s -m "your message"
```

This appends `Signed-off-by: Your Name <your@email>`. The DCO check enforces it on every
commit in a PR (bot commits are exempt).

## Reporting bugs / requesting features

Use the issue templates. For security issues, do **not** open a public issue — see
[`SECURITY.md`](./SECURITY.md).
