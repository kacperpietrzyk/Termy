# Security Policy

## Reporting a vulnerability

Please report security vulnerabilities **privately**, not via public issues:

- Preferred: GitHub's **private vulnerability reporting** (the "Report a vulnerability"
  button under this repository's **Security** tab).
- Alternatively: email **kacper.g.pietrzyk@gmail.com**.

Please include reproduction steps and affected versions. You'll get an acknowledgement,
and a fix or mitigation will be coordinated before any public disclosure.

## Scope notes

Termy is a single-user macOS app with no server and no telemetry. Auto-updates are signed
with a Sparkle EdDSA key held only by the maintainer; the public key ships in
maintainer-signed release builds (a from-source build has no key and auto-update is inert).
Secrets are stored only in the macOS/iCloud Keychain.

## Supported versions

The latest released version is supported.
