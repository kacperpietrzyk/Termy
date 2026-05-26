# THIRDPARTY-SYNTAX-HL.md — zsh-syntax-highlighting dependency audit

Feature FB-1 adds Warp-style terminal command syntax highlighting to Termy by vendoring
`zsh-syntax-highlighting` as a **runtime shell resource**. Unlike the FreeRDP admission
(a statically-linked compiled library), this dependency is sourced at runtime inside
Termy's controlled-ZDOTDIR interactive zsh session — it is a pure zsh script, not a
linked library and not a compiled artifact. The vendored copy is a pinned, minimised
subset of the 0.8.0 release: only the main entrypoint (`zsh-syntax-highlighting.zsh`)
and the main highlighter (`highlighters/main`) are included. All other highlighters
(`brackets`, `pattern`, `regexp`, `cursor`, `line`), documentation, and test data are
excluded from the committed copy.

**Authoritative pin source:** `vendor/zsh-syntax-highlighting/PINS` is the canonical
record of the tag and peeled commit SHA. When bumping the dependency, change `PINS`
first and then re-sync this document to match.

---

## zsh-syntax-highlighting 0.8.0

| Field | Value |
|---|---|
| Version | 0.8.0 |
| Tag | `0.8.0` |
| Peeled commit SHA | `db085e4661f6aafd24e5acb5b2e17e4dd5dddf3e` |
| Repository | https://github.com/zsh-users/zsh-syntax-highlighting |
| Licence | MIT |
| PINS pointer | `vendor/zsh-syntax-highlighting/PINS` |

### P1-gate audit

**Gate 1 — No telemetry / analytics.**
`zsh-syntax-highlighting` is a pure zsh script. It contains no telemetry, no analytics,
no crash reporting, and no update-check mechanism of any kind. There is no network code
in the library — it operates entirely on the zsh line editor's `$BUFFER` variable in
memory and produces ANSI highlight regions. No beacon, no phone-home, no diagnostic
reporting.

**Gate 2 — Offline / auditable: vendored verbatim at a pinned SHA; no build-time fetch.**
The dependency is vendored in full at `vendor/zsh-syntax-highlighting/` at the peeled
commit SHA recorded in `PINS`. There is no build-time fetch, no `git submodule`, and
no package manager invocation. The source is committed directly to the Termy repository
and is available entirely offline. No network access occurs at any point after the initial
vendor operation.

**Gate 3 — Minimized: only the main highlighter shipped.**
Only two items from the upstream release are included: the entrypoint
`zsh-syntax-highlighting.zsh` and the `highlighters/main` subdirectory (containing
`main-highlighter.zsh`). The five additional highlighters (`brackets`, `pattern`,
`regexp`, `cursor`, `line`), all documentation, images, and upstream test data are
excluded. This minimises the committed surface to only what FB-1 actually sources.

**Gate 4 — Secrets: operates only on the local `$BUFFER`; never reads or transmits secrets.**
`zsh-syntax-highlighting` operates exclusively on the zsh line editor buffer (`$BUFFER`)
to apply ANSI colour annotations. It does not read environment variables containing
credentials, does not access the filesystem beyond its own highlighter scripts, and
transmits nothing over the network. There is no mechanism by which it could read or
exfiltrate secrets.

**Gate 5 — Licence: MIT, redistribution-compatible with Termy's closed personal use.**
`zsh-syntax-highlighting` is released under the MIT licence. MIT is a permissive,
non-copyleft licence fully compatible with Termy's closed, non-MAS, Developer-ID
distribution model. The `LICENSE.md` file is retained verbatim in
`vendor/zsh-syntax-highlighting/LICENSE.md`.
