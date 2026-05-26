# CLAUDE.md — Termy

Working guidelines for any AI agent (Claude Code, Codex, or other) on the **Termy** project.
This is the single source of truth for agent guidelines; [`AGENTS.md`](./AGENTS.md) points here.

## What Termy is

A native macOS cockpit: a fast keyboard-first terminal with local AI assist, a lightweight
code editor, git support, a file explorer, a full SSH session manager, and an **embedded RDP**
session — in one private, account-less app.

See [`ROADMAP.md`](./ROADMAP.md) for product direction (what works today vs planned) and
[`CONTRIBUTING.md`](./CONTRIBUTING.md) for how to build, test, and submit changes (incl. the
FreeRDP build prerequisite and DCO).

## Non-negotiable principles

- **P1 — Absolute privacy.** No telemetry, no Termy account, no Termy server. Secrets only in
  macOS/iCloud Keychain. The only outbound traffic is what the user explicitly initiates
  (SSH/RDP to chosen hosts, user-launched CLI agents). Built-in AI runs **locally only**.
- **P2 — Keyboard first.** Every action reachable from the keyboard; ⌘K command center is the
  primary interface; shortcuts configurable.
- **P3 — Lean & fast.** Small footprint and fast startup. No heavy/unnecessary dependencies.
- **P4 — Native macOS.** Apple HIG, Keychain, Notifications, menu bar; must not feel like a
  web page in a window.
- **P5 — Private iCloud sync.** Config + secrets sync across the user's own Macs via their
  private iCloud (CloudKit private DB + iCloud Keychain). No intermediary server.

## Hard constraints

- **Platform:** macOS only. No Windows/Linux/web/mobile.
- **Audience:** single-user power-user. The **product** is a solo, privacy-absolute tool; the
  **project** is open-source (Apache-2.0) and open to contributors.
- **AI model:** built-in AI = local models only (LM Studio/Ollama class), fully offline.
  Heavy agentic work = orchestrate external CLI agents (**Claude Code**, **Codex**) using
  their own auth. Do **not** add cloud BYOK/API-key providers (out of scope at start).
- **Distribution:** Direct — Developer ID signed, notarized DMG, runs **outside App Sandbox**
  (required for unrestricted PTY, ssh-agent, embedded RDP), own auto-updater. Not Mac App Store.
- **UI language:** English.
- **RDP redirections:** core only — bidirectional clipboard + folder/drive + audio output.
  No microphone, printers, smartcard, USB.

## Working conventions for agents

- Stay within the principles above. Off-limits non-goals: do not add accounts, telemetry,
  cloud services, team/collab features, session sharing, a full IDE, or a full git client.
- Make surgical, minimal changes; match existing patterns; don't refactor unrelated code.
- Surface assumptions and trade-offs; define verifiable success criteria before building.
- Preserve the five principles in every change. If a request conflicts with them, flag it.
