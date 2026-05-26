# Phase-0 Spike REPORT — Command-spec-aware syntax highlighting

**Date:** 2026-05-21
**Branch:** `spec-highlight-spike` (worktree; local-only, not yet merged)
**Spec:** [`docs/superpowers/specs/2026-05-21-command-spec-aware-syntax-highlighting-design.md`](../../docs/superpowers/specs/2026-05-21-command-spec-aware-syntax-highlighting-design.md) — §4 gates, §5 target architecture.
**Plan:** [`docs/superpowers/plans/2026-05-21-command-spec-aware-syntax-highlighting-spike.md`](../../docs/superpowers/plans/2026-05-21-command-spec-aware-syntax-highlighting-spike.md)
**Upstream pin:** `withfig/autocomplete` @ `aef52acff84c45edde61ae610cc2c964802b9a38` (MIT; clone is gitignored, build-time scratch).

> **Bottom line:** **All four §4 gates PASS** (gate 3 after a small paint refinement found + fixed during the spike). Recommendation: **proceed to the §5+ production plan**, with concrete refinements surfaced by the spike (in-process result delivery, a paint rule that leaves default-colored roles to `main`, and finalized token rules) and a curate decision for Open Q1 (proposed cutoff: top ~100 + the author's CLIs). See [§Recommendation](#recommendation).

---

## Gate 1 — Conversion feasibility & size — ✅ PASS

**Mechanism (what worked).** The `withfig/autocomplete` checkout ships **no** pre-built JS (no `build/`, no compiled package in-tree). Node 24's native TS type-stripping alone is **insufficient**: a Fig spec's `import` of `@fig/autocomplete-generators` is a *runtime* dependency (not a type-only import), so stripping types still leaves an unresolved module. The working path is **in-process transpile + dependency stub**:

- `convert.mjs` runs **esbuild**'s bundle/transform API in-process (`bundle: true`, `write: false`, `format: 'esm'`).
- A small esbuild plugin **intercepts every `@fig/*` and `@withfig/*` import** and returns stub ESM with no-op named exports (generators, filepaths, etc.). Generators are runtime functions and are irrelevant to *static* structure, so stubbing them lets the spec module load without executing anything.
- `@withfig/autocomplete-types` is **type-only** and erases at transpile (no stub needed).
- The bundled module is loaded via a **`data:` URL dynamic `import()`** — no subprocess, no temp files. The static `completionSpec` object is then walked.

No child-process spawning is used; the whole pipeline is in-process. esbuild is pinned as a tracked devDependency (`package.json` / `package-lock.json`), so the spike is reproducible with `npm ci` (documented in `README.md`).

**Static-structure extraction.** `convert.mjs` recursively walks `subcommands[]` (incl. **nested** subcommands), `options[]` (all alias names; `args` present → takes-arg `1`, else `0`), and positional `args[]`. Generator functions and descriptions are **dropped**. Output is a compact, `source`-able zsh file of associative arrays. Key scheme settled by the spike (the plan's example was illustrative):

```
typeset -gA TS_GIT_SUB=( [commit]=1 [pull]=1 [push]=1 [remote]=1 ... )      # subcommands
typeset -gA TS_GIT_OPT=( [-C]=1 [--amend]=0 [--version]=0 ... )             # value = takes-arg (1/0)
typeset -gA TS_GIT_remote_SUB=( [add]=1 [remove]=0 [rename]=0 ... )         # nested under "remote"
typeset -gA TS_GIT_commit_OPT=( [-m]=1 [--message]=1 [--amend]=0 ... )      # options scoped to "commit"
```

`<CMD>` is upper-cased; the nested subpath is sanitized `[^A-Za-z0-9] → _` (e.g. `set-head` → `set_head`). All five outputs parse (`zsh -n`) and `source` cleanly with populated arrays. Verified against the source `git.ts`: aliases captured (`-m` **and** `--message`, both takes-arg), `remote`'s nested subcommands captured, takes-arg correct (`-C`=1, `--amend`=0).

**Sizes (converted, per the 5 representative commands):**

| Spec | Bytes | KB |
|---|---:|---:|
| `spec_git.zsh` | 22,199 | 21.7 |
| `spec_docker.zsh` | 36,981 | 36.1 |
| `spec_npm.zsh` | 11,879 | 11.6 |
| `spec_kubectl.zsh` | 25,879 | 25.3 |
| `spec_gh.zsh` | 16,617 | 16.2 |
| **Sum (5)** | **113,555** | **110.9** |

Average ≈ **22.7 KB/command**.

**Full-DB budget — corrected basis.** The DB has **715 top-level command spec files** (`src/*.ts`); the plan's "~1,484 specs" is the count of **all** `*.ts` including nested subcommand files. Because the converter **bundles each command's nested subcommands into a single `spec_<cmd>.zsh`** (esbuild follows the imports), the correct extrapolation unit is the **715 top-level commands**, not 1,484. So the plan's `×300 → ~34 MB` heuristic **double-counts** (it multiplies per-command sizes that already include nested content by the nested-inclusive file count).

- Upper-ish estimate: `715 × 22.7 KB ≈ 16 MB`.
- **But the 5 sampled CLIs (git/docker/npm/kubectl/gh) are among the largest, most option-dense specs in the ecosystem** — the median CLI spec is far smaller — so the realistic full-DB total is meaningfully **below 16 MB** (plausibly ~5–10 MB of plain text; gzip would cut that ~3–5×). This is **feasible to bundle but non-trivial**, which keeps Open Q1 (curate vs ship-all) a live decision (see Recommendation).
- **Runtime is unaffected by DB size** — specs are lazily `source`d per command (Gate 4), so a larger DB costs disk/bundle only, not per-keystroke time.

**Import-failure tolerance — ✅.** Pointing `convert.mjs` at a nonexistent/broken spec logs `[convert] ERROR loading spec for "<name>": ...` to **stderr** and exits non-fatally (`process.exitCode = 1; return` — not a hard crash). In the per-command batch loop each invocation is independent, so one bad spec does not abort the others. A partial DB is valid. ✓

---

## Gate 2 — In-zle matcher perf — ✅ PASS

**Matcher.** `termy_spec_classify <line>` (`matcher.zsh`): lazily `source`s `out/spec_<cmd>.zsh` for word-0 (cached, see Gate 4), splits the line with `${(z)}` (zsh shell-word split; quotes atomic), descends nested subcommands via zsh-native indirect expansion `${(P)varname}` (no `eval`), then classifies each remaining word as `option` (`-x` / `--long` / `--long=val` / bundled `-abc`), `option-argument` (value after a takes-arg option), or positional `argument`; `--` switches the rest to `argument`. Prints `start end role` triples — **0-based, half-open `[start,end)`** byte offsets. Roles: `command`, `subcommand`, `option`, `option-argument`, `argument`, `error`.

**Classification — all canonical + probe lines correct** (independently re-run by review):

| Input | Result |
|---|---|
| `git commit -m "x" --amend` | git=command, commit=subcommand, `-m`=option, `"x"`=option-argument, `--amend`=option |
| `git remote add origin url` | remote=subcommand → **nested** add=subcommand, origin/url=argument |
| `git pul` *(no trailing space)* | `pul` = **NOT error** (lenient prefix of `pull`) |
| `git --bogusflag` | `--bogusflag` = **error** (not a prefix of any in-scope flag) |
| `git psh` / `git pus` | `psh`=error, `pus`=subcommand (prefix of `push`) — discriminates correctly |
| `docker run -d nginx` | works for a different command's spec (not git-specific) |
| `frobnicate --x` | unknown command (no spec): word-0 still classified `command`, `--x` → `error`; no crash, exit 0 — **see limitation 3** |

**Validation rule settled** (resolves the spec §6 "finalize with the git prototype" item, and the apparent `pul`-vs-`--bogusflag` tension):

> The **trailing token** (the last word, when the input has **no trailing whitespace**) is validated **leniently**: it is flagged `error` only if it **cannot be a valid prefix of any expected key** at its position (subcommand slot → `TS_<CMD>_SUB`; option slot → `TS_<CMD>_OPT`). Direction is `key.startsWith(word)`. All **other** tokens (any non-last word, or any word when the input ends with whitespace) are **completed** and validated strictly: unknown subcommand/flag → `error`.

**Perf** (timed via `zsh/datetime` `$EPOCHREALTIME` deltas; line `git commit -m "x" --amend`):

| | Cold (first call, incl. lazy `source`) | Steady-state (N=1000, cached) |
|---|---:|---:|
| Observed | ~2–4.5 ms | **~1.1–1.2 ms/call** |

**Gate (target ≪ redraw budget, low single-digit ms, flag if >~5 ms): PASS** by a wide margin. Even the cold call (one-time per command per session) is under the bar.

**Limitations recorded (for §6 production finalization, not spike blockers):**
1. **Global-option-before-subcommand.** Once a takes-arg option is consumed, subcommand descent has already stopped — so in `git -C /tmp commit`, `commit` is classified `argument` rather than `subcommand`. This is a deliberate prototype simplification. Production needs a two-pass walk (skip leading global options to locate the subcommand) or a per-command global-options allowlist.
2. **Word-split fidelity.** `${(z)}` treats `"x"` as one token *including the quote characters*, so the option-argument offset spans the quotes. Production must reconcile token offsets with z-s-h's own tokenizer (which is already running as the `main` layer) so the spec layer and `main` agree on cell boundaries.
3. **Unknown-command engagement.** The standalone prototype unconditionally classifies word-0 as `command` and validates subsequent flags even when **no spec exists** (e.g. `frobnicate --x` → `command` + `error`). Spec §6 wants the opposite: when word-0 has no spec **and is not on PATH**, the spec layer should not engage at all (z-s-h `main` alone owns the line). Production must gate the paint hook on "word-0 has a spec OR is on PATH" before emitting any `command`/`error` entry — an unknown word-0 should not be painted green, nor a bare unknown flag reddened by the spec layer.

---

## Gate 3 — Composition with zsh-syntax-highlighting — ✅ PASS

**Custom-highlighter contract used.** z-s-h iterates `$ZSH_HIGHLIGHT_HIGHLIGHTERS` and, per name, calls `_zsh_highlight_highlighter_${name}_predicate` and `_zsh_highlight_highlighter_${name}_paint`. The spike registers `ZSH_HIGHLIGHT_HIGHLIGHTERS=(main termy_spec)` and defines `_zsh_highlight_highlighter_termy_spec_predicate` (returns 0) + `_zsh_highlight_highlighter_termy_spec_paint`. The **name is `termy_spec` consistently** in the array and both function suffixes (the plan's `termyspec`-vs-`termy_spec` inconsistency was resolved to `termy_spec`, matching spec §5.2). The paint hook is **live** (proven: a different input — `docker run -d nginx` — yields different, correct termy_spec entries).

**Headless drive.** The vendored z-s-h ships no `tests/` dir, so the probe pattern was derived from the source: set `BUFFER`, `CURSOR=${#BUFFER}`, `PENDING=0`, `KEYS_QUEUED_COUNT=0`, `_ZSH_HIGHLIGHT_PRIOR_BUFFER=`, seed `region_highlight` with a memo-tagged sentinel, then call `_zsh_highlight` and dump `region_highlight`.

**Both layers compose** — `region_highlight` for `git commit -m "hello" --amend /tmp` (after the gate-3 paint refinement, below):

```
# main layer (z-s-h):
0  3  fg=green       git
14 21 (none) + fg=yellow   "hello"  (string)
30 34 underline            /tmp     (path)
# termy_spec layer (structure only — emits NOTHING for "hello"/[14,21] or /tmp/[30,34]):
0  3  fg=green,bold  git=command          11 13 fg=242  -m=option
4  10 fg=cyan        commit=subcommand    22 29 fg=242  --amend=option
```

`main` keeps the **string** (`"hello"` → yellow) and **path** (`/tmp` → underline) as their **sole** owner; `termy_spec` owns only the **command structure** (command/subcommand/option/error). Offsets line up (both layers use the same 0-based half-open convention, so **no adjustment was needed**).

**Override semantics — confirmed via `man zshzle`:** *"If a particular character is affected by multiple specifications, the last specification wins."* z-s-h appends highlighters in `ZSH_HIGHLIGHT_HIGHLIGHTERS` order, so with `(main termy_spec)`, termy_spec entries come **last** and **win on overlapping cells**. This is exactly right for the **structure cells** (e.g. `git` at `[0,3]`: main `fg=green` then termy_spec `fg=green,bold` → bold wins, desired).

**Gate-3 paint refinement (found + fixed during the spike).** The same last-wins rule means a naïve paint that emits `fg=default` for the **foreground-default roles** (`option-argument`, `argument`) would **clobber `main`'s string/path styling** (e.g. termy_spec's `fg=default` on `[14,21]` overriding `main`'s `fg=yellow`). The fix: **the paint hook emits no `region_highlight` entry for `option-argument`/`argument`**, leaving those cells to `main` outright — so there is no overlap conflict on string/path cells at all, and `main` genuinely keeps them. With this, composition is clean (no garbled, negative, or out-of-range entries), matching the spec §5/§2 intent (spec layer owns structure, `main` owns shell tokens). This rule must carry into production (see Recommendation).

---

## Gate 4 — Lazy-load + cache — ✅ PASS

A global `_TS_LOADED` associative array guards the per-command `source`: `out/spec_<cmd>.zsh` is sourced **once per command per session**. **Proven:** with debug enabled (`_TS_DEBUG_LOAD=1`, a gated one-liner), two consecutive classifications of a `git …` line emit exactly **one** `[spec] sourcing git` line. ✓

**Architectural finding (the single most important production refinement).** The z-s-h paint hook **cannot capture the classifier via command substitution `$(...)`** — `$(...)` forks a subshell, so the classifier's `_TS_LOADED` writes happen in the child and are **lost on return**, defeating the cache (it would re-`source` on *every keystroke*). The spike worked around this by having the classifier write to a `mktemp` temp file that the paint hook reads back in the current shell (file is cleaned up on the normal paths).

→ **For production, the matcher should append its classifications to a global array IN-PROCESS** (e.g. `_TS_RESULT=()`) that the paint hook reads directly — **no command substitution, no temp file, no per-keystroke I/O**, and the session cache is preserved naturally. This both fixes the cache-correctness trap and removes the only I/O in the hot path. (Minor temp-file notes — missing interrupt `trap`, prefer `${TMPDIR:-/tmp}` on macOS — become moot under the in-process-array design and need not be carried forward.)

---

## Recommendation

**Proceed to author the §5+ production implementation plan.** All four gates pass; the approach is sound. Carry these spike-derived revisions into that plan:

1. **§5.2 — matcher result delivery (REQUIRED).** Specify that the matcher writes role triples into a **global array in-process** for the paint hook to read — not stdout capture. This is necessary for the lazy-load cache to actually hold per session and removes per-keystroke I/O. (Gate-4 finding.) **Additionally, the paint hook must emit no `region_highlight` entry for the foreground-default roles (`option-argument`, `argument`)** — otherwise the last-wins rule clobbers `main`'s string/path styling. Only `command`/`subcommand`/`option`/`error` get spec-layer entries. (Gate-3 finding.)

2. **§6 — finalize token rules.** Adopt the spike's trailing-token **lenient prefix rule** (error only if not a valid prefix of an in-scope key; completed tokens strict). Add **global-option-before-subcommand** handling (two-pass: skip leading global options to find the subcommand). **Gate the spec layer on word-0 recognition** — when word-0 has no spec and is not on PATH, emit nothing (the prototype currently still paints word-0 `command` and reddens unknown flags; see Gate-2 limitation 3). Reconcile token **offsets with z-s-h's tokenizer** so the spec layer and `main` agree on cell boundaries (esp. quoted option-arguments). (Gate-2 findings.)

3. **Open Q1 — bundle scope: recommend CURATE, proposed cutoff = top ~100 commands + the author's own CLIs.** Corrected estimate: ~715 top-level commands; the 5 sampled are among the largest, so a ship-all DB is plausibly ~5–16 MB of plain text (less, gzipped) — feasible but not negligible against PRD **P3 (lean)**. Since runtime cost is independent of DB size (lazy per-command source), the trade-off is purely bundle/disk vs coverage. **Proposed cutoff: convert the top ~100 most-common CLIs (the long tail of 715 is rarely typed interactively) plus an explicit author-CLI list** — this realistically lands the bundle around ~1–3 MB (most specs are far smaller than the sampled 5) while covering the overwhelming majority of typed commands. The converter already tolerates a partial set (Gate 1), so the list is just a build input and can grow later. If the author prefers maximum coverage and ~5–16 MB is acceptable, ship-all is technically fine. **Final number is the author's call; top-100 is the lean default.**

4. **Privacy/licensing (carry into §5, not the spike):** the Fig clone + Node converter are **build-time only**; converted specs are bundled text with no runtime network. A `THIRDPARTY-SPECS.md` (Fig = MIT, pinned commit `aef52ac…`) is a production deliverable.

**No revision invalidates the spec §5 architecture** — the in-zsh synchronous matcher + layered `(main termy_spec)` model holds. The revisions are refinements within it.

---

## Spike artifacts (kept, like `script/f4-spike/`; not wired into the app)

| File | Role |
|---|---|
| `README.md` | Workspace doc + pinned `withfig` SHA + reproduce steps |
| `convert.mjs` | Fig TS spec → compact `spec_<cmd>.zsh` (esbuild transpile + generator stub) |
| `out/spec_{git,docker,npm,kubectl,gh}.zsh` | The 5 converted sample specs |
| `matcher.zsh` | `termy_spec_classify` prototype classifier + validation |
| `perf.zsh` | Per-keystroke perf harness |
| `compose.zsh` | z-s-h `(main termy_spec)` composition + lazy-load probe |
| `package.json` / `package-lock.json` | Pins esbuild (build-time dep) for reproducibility |

Gitignored (build-time scratch): `autocomplete/` (the clone), `node_modules/`.
