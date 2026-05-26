# THIRDPARTY-RDP.md — FreeRDP transitive dependency audit

Milestone M5 replaces Termy's bespoke hand-rolled RDP stack with a statically-linked
FreeRDP build. This document records the **exact, pinned, minimised transitive dependency
set** admitted by M5, audited against all five P1-gate criteria from the umbrella
dependency policy (§1 of `docs/superpowers/specs/2026-05-18-core-restructure-vetted-deps-design.md`).

This document **resolves the umbrella §1 "(OpenSSL et al.)" placeholder** to the concrete,
minimised list below. With the cmake flags in `script/build_freerdp.sh`, FreeRDP 3.26.0's
mandatory runtime transitive set reduces to **three entries only**:

- FreeRDP 3.26.0 (includes `winpr3`, which ships inside FreeRDP and is not third-party)
- OpenSSL 3.5.3
- zlib 1.3.1

No Kerberos, libusb, cJSON, FFmpeg/codec, SDL, X11/Wayland, PCSC/CUPS, or AAD/webview
linkage — all disabled at cmake by the `build_freerdp.sh` flag set.

**Authoritative pin source:** `vendor/freerdp/PINS` is the machine-verified canonical
source of these tags and commit SHAs — `build_freerdp.sh` greps it and aborts non-zero on
any mismatch. The tags/SHAs reproduced in the per-dependency tables below mirror `PINS`
for audit readability; when bumping a dependency, change `vendor/freerdp/PINS` first (it
is canonical) and then re-sync this document to match.

---

## 1. FreeRDP 3.26.0

| Field | Value |
|---|---|
| Version | 3.26.0 |
| Tag | `3.26.0` |
| Peeled commit SHA | `3f6d7cb1f8973cc84c66b258a9a61c4e2b2f30a6` |
| Repository | https://github.com/FreeRDP/FreeRDP |
| Licence | Apache-2.0 |
| PINS entry | `vendor/freerdp/PINS` (FREERDP block) |

### P1-gate audit

**Gate 1 — No telemetry / analytics.**
FreeRDP 3.26.0 contains no telemetry, crash-reporting, or analytics code. The cmake build
disables `WITH_AAD=OFF` and `WITH_WEBVIEW=OFF`, removing the only code paths that could
contact a Microsoft/Azure endpoint (Azure AD auth flow, webview-based OAuth). No beacon,
update check, or diagnostics call exists in the minimised build.

**Gate 2 — No library-initiated network beyond what the user explicitly initiates.**
FreeRDP performs exactly the TCP/TLS connection the user initiates to their own RDP host —
informationally the same traffic class the bespoke stack already produced. No analytics
endpoint, no NTP, no OCSP stapling to a Microsoft CA outside the user-directed connection.
`WITH_KRB5=OFF` removes Kerberos DNS/KDC lookups. `WITH_AAD=OFF`/`WITH_WEBVIEW=OFF`
removes all Microsoft-cloud-directed flows.

**Gate 3 — Auditable source (open-source, known reputation).**
FreeRDP is a mature, widely-audited open-source RDP client (Apache-2.0, active since 2009,
used in production by rdesktop, Guacamole, and others). Source is public on GitHub at a
known canonical URL. The exact commit is SHA-pinned and verified at build time by
`build_freerdp.sh`. The Windows RDP protocol implementation is the most security-critical
surface in Termy; replacing a 6,300-line bespoke hand-rolled implementation with
FreeRDP's battle-tested engine is strictly risk-reducing.

**Gate 4 — Permissive licence compatible with closed distribution.**
Apache-2.0. Fully compatible with closed, non-MAS, Developer-ID distribution. No GPL,
no LGPL, no viral clause, no attribution requirement beyond including the NOTICE file
(satisfied by this document). `winpr3` ships inside FreeRDP under the same Apache-2.0
licence.

**Gate 5 — Replaces a material bespoke security/quality-critical surface.**
FreeRDP replaces ~6,300 lines of hand-rolled CredSSP/NTLMv2/SPNEGO/DER/MCS/channel codec
code in `RDPSessionDescriptor.swift` — the single largest hand-rolled security-critical
body in the Termy repository, validated only by unit vectors and never against a real RDP
server. This is the canonical gate-#5 case: retiring bespoke crypto/protocol code in
favour of a widely-audited library is the core reason gate #5 exists.

---

## 2. OpenSSL 3.5.3

| Field | Value |
|---|---|
| Version | 3.5.3 |
| Tag | `openssl-3.5.3` |
| Peeled commit SHA | `c4da9ac23de497ce039a102e6715381047899447` |
| Repository | https://github.com/openssl/openssl |
| Licence | Apache-2.0 (since OpenSSL 3.0, released 2021-09) |
| PINS entry | `vendor/freerdp/PINS` (OPENSSL block) |

OpenSSL 3.5 is the current LTS line (3.5.0 LTS announced 2025-04); 3.5.3 is the latest
stable patch. This satisfies the plan's "current stable, OpenSSL 3.x" requirement.

### P1-gate audit

**Gate 1 — No telemetry / analytics.**
OpenSSL 3.x contains no telemetry. The `no-engine no-fips` configure flags disable the
legacy engine API and FIPS module — removing the only code paths that might invoke external
validation or provider loading. No analytics or reporting code exists in the minimised
build.

**Gate 2 — No library-initiated network beyond what the user explicitly initiates.**
OpenSSL performs TLS operations on connections the application opens — it does not initiate
any network connection autonomously. OCSP stapling happens only on connections Termy opens
to the user's RDP server; no background certificate validation traffic to external CAs is
initiated. `no-engine` removes dynamic provider loading that could reach external URIs.

**Gate 3 — Auditable source (open-source, known reputation).**
OpenSSL is the most widely-used TLS/crypto library in the world, audited continuously by
the OpenSSL Security Team, OSTIF, and independent researchers. Apache-2.0 release since
3.0 (2021). Source at the canonical https://github.com/openssl/openssl. Exact commit
SHA-pinned and verified at build time.

**Gate 4 — Permissive licence compatible with closed distribution.**
Apache-2.0 (since 3.0). Fully compatible with closed, non-MAS, Developer-ID distribution.
The old dual SSLeay/OpenSSL licence that required credit in advertising was retired at 3.0.

**Gate 5 — Replaces a material bespoke security/quality-critical surface.**
OpenSSL is a mandatory transitive dependency of FreeRDP 3.x (TLS for the RDP transport
layer). Admitting it is a direct consequence of retiring the hand-rolled `RDPByteTransport`
+ SecureTransport TLS wrapper (269 lines). It does not introduce additional surface; it
replaces bespoke TLS wiring with a standard, audited library.

---

## 3. zlib 1.3.1

| Field | Value |
|---|---|
| Version | 1.3.1 |
| Tag | `v1.3.1` |
| Peeled commit SHA | `51b7f2abdade71cd9bb0e7a373ef2610ec6f9daf` |
| Repository | https://github.com/madler/zlib |
| Licence | zlib licence (permissive, BSD-class) |
| PINS entry | `vendor/freerdp/PINS` (ZLIB block) |

### P1-gate audit

**Gate 1 — No telemetry / analytics.**
zlib is a pure data-compression library with no telemetry, no reporting, and no network
code. It compresses and decompresses bytes in memory. No analytics code exists.

**Gate 2 — No library-initiated network beyond what the user explicitly initiates.**
zlib initiates no network connections. It is a compression algorithm implementation only.

**Gate 3 — Auditable source (open-source, known reputation).**
zlib (by Jean-loup Gailly and Mark Adler) is one of the most widely-used and audited
libraries in existence, included in virtually every operating system and TLS implementation.
Canonical source at https://github.com/madler/zlib. Exact commit SHA-pinned and verified
at build time.

**Gate 4 — Permissive licence compatible with closed distribution.**
The zlib licence is a permissive, non-copyleft licence (BSD-class). It is fully compatible
with closed, non-MAS, Developer-ID distribution. The gate's stated examples ("MIT /
Apache-2.0 / BSD") are illustrative, not exhaustive — the zlib licence is in the same
permissive-non-copyleft family and is explicitly sanctioned by the M5 plan: "zlib (zlib
licence)".

**Gate 5 — Replaces a material bespoke security/quality-critical surface.**
zlib is a mandatory transitive dependency of FreeRDP 3.x (RDP protocol-level compression).
It is not an independent admission; it is a direct consequence of using FreeRDP to retire
the bespoke RDP surface (gate #5 for FreeRDP applies transitively).

---

## cmake flag provenance

The set of cmake flags in `script/build_freerdp.sh` was derived from FreeRDP's own
`ci/cmake-preloads/config-macosx.txt` minimal-build basis and hardened for a
library-only, no-UI, static-archive build. Every optional feature that would introduce
an additional transitive dependency is explicitly disabled. The resulting mandatory
transitive set is exactly the three entries documented above.

## Build integrity

Sources are fetched from canonical GitHub URLs, SHA-verified against the peeled commit
SHAs recorded in `vendor/freerdp/PINS`, and built fully offline (no network during
cmake/make). `build_freerdp.sh` aborts non-zero on any SHA mismatch — no "build whatever
HEAD is" fallback exists. Static archives only (`BUILD_SHARED_LIBS=OFF`); no dynamic
libraries are produced or embedded.
