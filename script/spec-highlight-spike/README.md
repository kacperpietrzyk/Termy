# spec-highlight-spike

Phase-0 de-risking spike for the command-spec-aware syntax highlighting feature (FB-1 follow-up).

## Purpose

This directory is **throwaway exploration** that feeds `REPORT.md` (produced at Task 5).
Nothing here is wired into the Termy app. The spike validates whether a Fig-spec DB can
drive per-token colour classification inside zsh-syntax-highlighting without regressing
shell startup time or the existing z-s-h composition.

## Tasks

| Task | Description |
|------|-------------|
| 1 | Spike workspace + prerequisites + pinned Fig checkout (this task) |
| 2 | Fig→zsh converter: extract subcommands/flags/args from a Fig spec TS file |
| 3 | In-zsh matcher prototype: feed one spec into a zsh function that classifies tokens |
| 4 | z-s-h composition: plug the classifier into the vendor/zsh-syntax-highlighting pipeline |
| 5 | Measurement + REPORT.md |

## Pinned `withfig/autocomplete` checkout

```
SHA: aef52acff84c45edde61ae610cc2c964802b9a38
```

The clone lives at `script/spec-highlight-spike/autocomplete/` and is **gitignored** —
it is build-time scratch only. To recreate it:

```bash
git clone --depth 1 https://github.com/withfig/autocomplete script/spec-highlight-spike/autocomplete
# then verify: git -C script/spec-highlight-spike/autocomplete rev-parse HEAD
# expected:    aef52acff84c45edde61ae610cc2c964802b9a38
```

`node_modules/` (if created by later tasks) is also gitignored.

## Running the converter (Task 2)

`convert.mjs` transpiles a Fig spec TS file in-process via **esbuild**, which is
recorded as a dev dependency in `package.json` / `package-lock.json` (both tracked).
Install it once before running the converter:

```bash
cd script/spec-highlight-spike
npm ci          # or: npm i  — installs esbuild into the gitignored node_modules/
```

Then convert a command's spec (writes `out/spec_<cmd>.zsh`):

```bash
node convert.mjs git
# or for the five sampled commands:
for c in git docker npm kubectl gh; do node convert.mjs "$c"; done
```

## This directory is throwaway

Do not graduate any file here into the main app without an explicit design + review cycle.
All findings are summarised in `REPORT.md` after Task 5.
