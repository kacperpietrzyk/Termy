# Third-party fonts

Termy bundles the following fonts. Bundled = **zero network**: registered at
launch via `ATSApplicationFontsPath`. No font CDN, consistent with PRD §4 P1.

## Geist & Geist Mono

- **Source:** Vercel — https://github.com/vercel/geist-font
- **License:** SIL Open Font License 1.1 (`Resources/Fonts/OFL.txt`)
- **Faces shipped:** Geist Regular/Medium/SemiBold; Geist Mono Regular/Medium.
- **Use:** UI + UI-mono text in the v3 design system. Falls back to SF Pro /
  SF Mono when a face fails to load.
- **Curated-allowlist note:** admitted under the same dependency/privacy gate as
  SwiftTerm, Sparkle, and FreeRDP — bundled, offline, no telemetry.

> **Vendored.** The five static OTFs (`Geist-Regular.otf`, `Geist-Medium.otf`,
> `Geist-SemiBold.otf`, `GeistMono-Regular.otf`, `GeistMono-Medium.otf`) + `OFL.txt`
> live in `Resources/Fonts/`, copied unmodified from the source repo. PostScript
> names verified against the names `Typography.swift` looks up. The build scripts
> stage them into the `.app` and register via `ATSApplicationFontsPath`. (If they
> are ever removed, the build soft-warns and the UI falls back to SF — it never fails.)
>
> **To refresh:** re-fetch the same five faces + `OFL.txt` from the source repo into
> `Resources/Fonts/` (e.g. a `--filter=blob:none --no-checkout` clone, then
> `git checkout HEAD -- fonts/Geist/otf/… fonts/GeistMono/otf/… OFL.txt`).
