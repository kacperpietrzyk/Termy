# Releasing Termy

Termy ships as a Developer ID-signed, notarized DMG with a Sparkle auto-update
feed. Releases are cut **locally** — all keys stay in the maintainer's Mac
Keychain; nothing is stored in GitHub Secrets. `script/release.sh` is the single
command and it **refuses to publish** any build that fails the PRD
direct-distribution audit (`dist/Termy-<v>.distribution.json` →
`satisfiesDirectDistributionPRD`).

## One-time owner setup

1. **Developer ID certificate.** Install the *Developer ID Application*
   certificate + private key into the login Keychain (Xcode ▸ Settings ▸
   Accounts ▸ Manage Certificates, or import the `.p12`). Confirm:
   `security find-identity -v -p codesigning | grep "Developer ID Application"`.
   Export its full name (e.g. `Developer ID Application: Your Name (TEAMID)`)
   as `DEVELOPER_ID_APPLICATION`.

2. **Notarization profile.** Create a keychain profile named `TermyNotary`:
   `xcrun notarytool store-credentials TermyNotary` (use an App Store Connect
   API key, or your Apple ID + an app-specific password + Team ID). Verify:
   `xcrun notarytool history --keychain-profile TermyNotary`.

3. **Sparkle EdDSA keys.** Generate the update-signing key pair once:
   `./.build/checkouts/Sparkle/bin/generate_keys` (path may differ — it ships in
   Sparkle's `bin/`; `find .build -name generate_keys`). The **private** key is
   stored in the Keychain; copy the printed **public** key. The public key is safe
   to commit, so pin it once by adding a default line to the config block in
   `script/release.sh` (just below the `PAGES_BRANCH=…` line), replacing the
   "must come from the env" comment:
   `SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-<your-public-key>}"`. Future
   releases then need only `DEVELOPER_ID_APPLICATION` in the env (or pass
   `SPARKLE_PUBLIC_ED_KEY` per-run, as in "Cutting a release" below).
   `sign_update` reads the **private** key from the Keychain at release time.

4. **GitHub Pages feed.** Bootstrap the `gh-pages` branch (see the repo's
   gh-pages bootstrap commit) and push it, then enable **Settings ▸ Pages ▸
   Branch: gh-pages /(root)**. Confirm
   `https://kacperpietrzyk.github.io/Termy/appcast.xml` resolves. This URL is the
   `SUFeedURL` baked into every release build.

## Cutting a release

The signing identity and the EdDSA public key are pinned as defaults in
`script/release.sh`, so a release needs only the version:

```bash
script/release.sh v0.2.0
```

`release.sh` will:

1. **Preflight** — abort if the identity, notary profile, EdDSA key, or `gh`
   auth is missing (before any build).
2. **Build** via `script/package_dmg.sh`: release build → embed + inside-out
   sign Sparkle helpers → Developer ID sign (App Sandbox **off**, hardened
   runtime **on**) → DMG → `notarytool submit --wait` → `stapler staple` →
   EdDSA-sign the DMG into `appcast.xml`.
3. **Gate** — refuse to publish unless `satisfiesDirectDistributionPRD: true`.
4. **Publish** — `gh release create v0.2.0 dist/Termy-0.2.0.dmg` (DMG asset) and
   push the updated `appcast.xml` to `gh-pages`.

During signing, macOS may show **Keychain access prompts** (for the Developer ID
key and the EdDSA key) — approve them. When the agent runs releases, the owner
clicks these.

## Versioning

A single semver `vX.Y.Z` drives both `CFBundleShortVersionString` and
`CFBundleVersion`. Sparkle compares the version strings, so each release must be
a strictly higher semver than the last. The feed carries only the latest release
(sufficient for "is a newer version available").

## Verifying auto-update (owner live gate)

With a notarized `X.Y.Z` installed, publish `X.Y.(Z+1)`, then in the app choose
**Check for Updates…** and confirm Sparkle downloads and installs the new DMG.
This live round-trip is owner-verified, not auto-claimed.
