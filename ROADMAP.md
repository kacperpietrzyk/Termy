# Termy — Roadmap

Termy *aims to be* one keyboard-first cockpit for a developer's whole macOS workflow —
local and remote — in a single native, private app: a modern terminal with built-in AI
assist and CLI-agent orchestration (Claude Code / Codex), a light code editor, git,
a file explorer, a full SSH manager, and an embedded RDP desktop, with private iCloud
sync. No telemetry, no account, no Termy server.

> ⚠️ **Early beta.** Termy is in early-stage development. The terminal core is the most
> developed part; most surrounding modules are partial, scaffolding, or not yet built, and
> the UI is mid-redesign. Expect bugs, missing features, and breaking changes. The buckets
> below reflect the current state honestly — they are direction, not commitments or dates.

## Principles (non-negotiable)

- **Privacy is absolute** — zero telemetry, no account, no Termy server. Secrets live
  only in the macOS/iCloud Keychain. The built-in AI runs locally; the only network
  traffic is what you initiate (SSH/RDP to your hosts, CLI agents with their own auth,
  your private iCloud sync).
- **Keyboard-first** — every action reachable from the keyboard; the command palette
  (⌘K) is the primary interface.
- **Light & fast** — small footprint, instant start, no heavy unnecessary dependencies.
- **Native macOS** — Apple HIG, Keychain, Notifications, menu bar.
- **macOS only.** Single-user. No teams, no session sharing, no cloud dashboard.

## Working today (early, expect rough edges)

The terminal core is the most developed area — present in code and covered by tests, but
still early and unpolished:

- Native terminal (SwiftTerm engine): multiple tabs/sessions, true-color, search,
  shell integration (cwd + command markers), inline autosuggestions (ghost text),
  keyboard-driven completion menu with live zsh completion data, command syntax
  highlighting, and a Warp-style block output mode.
- Command history with frecency ranking.
- Auto-update plumbing via Sparkle (active only in maintainer-signed builds).

## Partial / in progress (not fully working yet)

- CLI-agent orchestration (Claude Code / Codex): launch + lifecycle controls and the data
  layer exist; the UI is unpolished and not fully validated.
- Embedded RDP via FreeRDP: the integration is wired up, but a live end-to-end session
  (including audio) has not been verified yet.
- Private iCloud sync: scaffolding only (CloudKit private DB + iCloud Keychain) — not a
  working sync yet.
- UI redesign (v3): an in-progress, module-by-module rework; much of the app does not yet
  match its intended design.

## Planned / not yet built

- Deeper SSH manager: connection vault, jump/bastion, port forwarding, SFTP file browser.
- Light code editor with syntax highlighting and AI assist.
- Git panel (status/stage/commit/push, AI commit messages).
- Built-in local-model AI assistant (natural-language → command, explain-error → fix).
- Tiling panes and named workspaces.
- Markdown rendered view; session + scrollback restore; Secure-Enclave SSH keys.

See open issues for current work. Contributions welcome — read CONTRIBUTING.md.
