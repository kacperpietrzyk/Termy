# THIRDPARTY-SPECS.md — withfig/autocomplete spec DB audit

Feature FB-1 (command-spec-aware syntax highlighting) incorporates a curated subset of
the `withfig/autocomplete` TypeScript spec database, converted at regeneration time to
plain zsh associative arrays. Unlike the FreeRDP admission (a statically-linked compiled
library) or zsh-syntax-highlighting (a runtime-sourced zsh script), the withfig source is
**regeneration-time only** — it is cloned and processed by `script/convert-fig-specs.mjs`
when explicitly re-running spec generation, but is **never fetched at packaging time** and
carries **no runtime footprint**.

The vendored artifact that ships in the DMG is the converted output under
`vendor/specs/out/` — a set of plain `spec_<cmd>.zsh` files containing only zsh
`typeset -gA` declarations. No TypeScript, no Fig tooling, no autocomplete framework code
reaches the packaged application.

**Authoritative pin source:** `vendor/specs/PINS` is the canonical record of the pinned
commit SHA. When regenerating specs, change `PINS` first and then re-sync this document
to match.

---

## withfig/autocomplete (pinned SHA aef52acff84c45edde61ae610cc2c964802b9a38)

| Field | Value |
|---|---|
| Version | (no release tag — pinned by SHA) |
| Peeled commit SHA | `aef52acff84c45edde61ae610cc2c964802b9a38` |
| Repository | https://github.com/withfig/autocomplete |
| Licence | MIT |
| PINS pointer | `vendor/specs/PINS` |

### P1-gate audit

**Gate 1 — No telemetry / analytics.**
`withfig/autocomplete` is a TypeScript/JSON spec database describing CLI command
arguments and subcommands. It contains no telemetry, analytics, crash-reporting, or
update-check mechanism of any kind. The conversion tooling (`script/convert-fig-specs.mjs`)
reads the spec source and emits plain zsh text; it performs no network calls during conversion.
No beacon, no phone-home, no diagnostic reporting — neither in the source database nor in
the generated zsh artifact.

**Gate 2 — Offline / auditable: regen-time only; no fetch at packaging time; no runtime network.**
The `withfig/autocomplete` clone is **regeneration-time only**. Running
`script/convert-fig-specs.mjs --clone <src-dir>` requires an existing local clone of the
package's `src/` tree — it is never fetched as part of `package_dmg.sh` or any packaging step. The committed `vendor/specs/out/` directory
is the vendored artifact: it is a static snapshot committed directly to the Termy repository
and is available entirely offline. No network access occurs at packaging time or at runtime.
The generated zsh files are sourced by `termy-spec-highlighter.zsh` from the local
`$TERMY_SPEC_DIR` directory only.

**Gate 3 — Minimized: only the curated command set converted; generator infrastructure dropped.**
Only the commands listed in `script/spec-commands.txt` are converted. Subcommand
generators (JavaScript generator functions), long-form prose descriptions, and argument
suggestion metadata are dropped during conversion — only the associative-array membership
tables (subcommand names, option names, and option takes-arg flags) are retained. The
withfig/autocomplete source tree itself (TypeScript source, test data, framework code) is
never committed to the Termy repository. The `vendor/specs/out/` artifact is the minimal
information needed for spec-aware syntax classification.

**Gate 4 — Secrets: operates only on the local command buffer; never reads or transmits secrets.**
The generated `spec_<cmd>.zsh` files contain only static zsh associative array
declarations. They do not read environment variables, do not access the filesystem beyond
their own declarations during source, and transmit nothing over the network. The
`termy-spec-highlighter.zsh` classifier operates exclusively on the zsh line-editor buffer
(`$BUFFER`) in memory and produces classification triples; it has no mechanism to read or
exfiltrate secrets.

**Gate 5 — Licence: MIT, redistribution-compatible with Termy's closed personal use.**
`withfig/autocomplete` is released under the MIT licence. MIT is a permissive,
non-copyleft licence fully compatible with Termy's closed, non-MAS, Developer-ID
distribution model. The converted `vendor/specs/out/` zsh files are derived works of the
MIT-licensed spec source and carry the same licence terms.
