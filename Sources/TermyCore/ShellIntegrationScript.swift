import Foundation

public enum ShellIntegrationScript {
    /// FB-1: composes the ZDOTDIR `.zshrc` Termy injects for local zsh sessions.
    /// `highlightStyles` are `ZSH_HIGHLIGHT_STYLES[...]` lines from `SyntaxHighlightStyleMap`;
    /// pass `[]` to fall back to zsh-syntax-highlighting's own defaults.
    /// `specStylesBlock` is the `typeset -gA TERMY_SPEC_STYLES …` block from `SpecHighlightPalette`;
    /// pass `""` to omit (existing callers default to empty).
    public static func zsh(highlightStyles: [String] = [], specStylesBlock: String = "") -> String {
        let styleBlock = highlightStyles.isEmpty
            ? ""
            : "typeset -gA ZSH_HIGHLIGHT_STYLES\n" + highlightStyles.joined(separator: "\n") + "\n"
        let specBlock = specStylesBlock.isEmpty ? "" : specStylesBlock + "\n"
        return """
        autoload -Uz add-zsh-hook add-zle-hook-widget
        # Slice-2c / Bug 1+3: probe the Warp context fields for the CURRENT $PWD into
        # the caller's locals `termy_branch`/`termy_gitstatus`/`termy_node` (zsh
        # dynamic scope — caller declares them `local`). Every probe is cheap, quiet,
        # and fail-open; `--no-optional-locks` avoids index-lock contention.
        termy_probe_context() {
          termy_branch="$(git --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null)"
          termy_gitstatus=''
          if [[ -n $termy_branch ]]; then
            # T1 / Warp ±N parity: emit a COUNT of working-tree changes instead of a
            # bare dirty flag. `grep -c .` yields '0' on a clean tree (Warp shows ± 0
            # in-repo) and the integer otherwise. Stays cheap (`--no-optional-locks`),
            # fail-open: a git error leaves the count empty/zero and the field is
            # only emitted when in a repo (guarded by $termy_branch above).
            termy_gitstatus="$(git --no-optional-locks status --porcelain --untracked-files=all 2>/dev/null | grep -c .)"
          fi
          # node version is session-constant; probe once, then reuse the cached value.
          if [[ -z $TERMY_NODE_PROBED ]]; then
            TERMY_NODE_PROBED=1
            command -v node >/dev/null 2>&1 && TERMY_NODE_VER="$(node --version 2>/dev/null)"
          fi
          # Bug 3 / Warp parity: surface node ONLY inside a node-flavored project —
          # a package.json found walking up to the git root. Other runtimes
          # (Cargo.toml→Rust, requirements.txt→Python, …) = a separate multi-runtime
          # feature, intentionally NOT built here. Version stays session-constant
          # (nvm-per-dir unhandled, pre-existing limit).
          termy_node=''
          if [[ -n $TERMY_NODE_VER ]]; then
            local termy_d="$PWD"
            while [[ -n $termy_d && $termy_d != / ]]; do
              if [[ -f $termy_d/package.json ]]; then termy_node="$TERMY_NODE_VER"; break; fi
              [[ -e $termy_d/.git ]] && break   # stop at the repo root
              termy_d="${termy_d:h}"
            done
          fi
        }
        termy_preexec() {
          # Per-command context for the Warp block header. Real fields go FIRST and
          # the command LAST so a command containing `;branch=…`/`;cmd=…` can't
          # shadow a legit field (parser is first-wins).
          local termy_branch termy_gitstatus termy_node
          termy_probe_context
          printf '\\033]133;C;branch=%s;gitstatus=%s;node=%s;cmd=%s\\007' \\
            "$termy_branch" "$termy_gitstatus" "$termy_node" "$1"
        }
        termy_precmd() {
          local termy_status=$?
          # Bug 1: carry LIVE prompt context on D too (precmd fires before EVERY
          # prompt incl. the first), so the pinned input bar shows the branch right
          # after a `cd` — and clears it on `cd` into a non-repo (empty fields).
          local termy_branch termy_gitstatus termy_node
          termy_probe_context
          printf '\\033]133;D;exit=%d;pwd=%s;branch=%s;gitstatus=%s;node=%s\\007' \\
            "$termy_status" "$PWD" "$termy_branch" "$termy_gitstatus" "$termy_node"
        }
        add-zsh-hook preexec termy_preexec
        add-zsh-hook precmd termy_precmd
        # F-1/FB-1: publish the live line-editor buffer (inline ghost text) AND
        # zsh-syntax-highlighting's region_highlight (live block coloring). The
        # hook is registered at the END of this script — AFTER z-s-h — so that
        # region_highlight is already computed for the current redraw.
        termy_buffer_publish() {
          # Subshell forks base64+tr per redraw; recompute is debounced store-side.
          local termy_b termy_hl
          termy_b="$(print -rn -- "$BUFFER" | base64 | tr -d '\\n')"
          # OSC bytes are consumed by Termy's tap before the emulator renders — safe from within zle.
          printf '\\033]133;T;b=%s;c=%d;n=%d\\007' "$termy_b" "$CURSOR" "${#BUFFER}"
          # FB-1: region_highlight entries joined by `|`, base64'd. Empty when no
          # highlighting is active → Termy renders the live block uncolored.
          termy_hl="$(print -rn -- "${(j:|:)region_highlight}" | base64 | tr -d '\\n')"
          printf '\\033]133;H;r=%s\\007' "$termy_hl"
        }
        # v3 §6.1: match the block-terminal prompt (user@host:cwd ❯) so the live
        # SwiftTerm prompt reads the same as the rendered command-block cards.
        # `❯` replaces `%#` (purely visual; OSC 133 C/D marks drive parsing).
        PROMPT='%n@%m:%~ ❯ '
        # Block-model fix: zsh's PROMPT_SP "preserve partial line" feature always
        # emits PROMPT_EOL_MARK (`%`) + pad + CR before each prompt. On a raw
        # terminal the prompt overwrites it, but Termy's command-block tap captures
        # the `%` literally as trailing output of the just-finished block (the CR +
        # overwrite lands in the next block). Disable it so blocks stay clean.
        unsetopt PROMPT_SP 2>/dev/null
        PROMPT_EOL_MARK=''
        # FB-1: Warp-style command syntax highlighting via vendored zsh-syntax-highlighting
        # (zsh-only). Styles derive from the active Termy theme. The source is guarded so a
        # missing resource never blocks shell start (fail-open).
        ZSH_HIGHLIGHT_HIGHLIGHTERS=(main termy_spec)
        ZSH_HIGHLIGHT_MAXLENGTH=4096
        \(styleBlock)if [[ -n "$TERMY_SYNTAX_HL_DIR" && -r "$TERMY_SYNTAX_HL_DIR/zsh-syntax-highlighting.zsh" ]]; then
          source "$TERMY_SYNTAX_HL_DIR/zsh-syntax-highlighting.zsh"
        fi
        # Spec-layer: default no-op stubs so z-s-h never errors when $TERMY_SPEC_DIR is
        # absent (unit tests, staged resource missing). The real highlighter redefines both.
        _zsh_highlight_highlighter_termy_spec_predicate() { return 1; }
        _zsh_highlight_highlighter_termy_spec_paint() { :; }
        \(specBlock)if [[ -n "$TERMY_SPEC_DIR" && -r "$TERMY_SPEC_DIR/termy-spec-highlighter.zsh" ]]; then
          source "$TERMY_SPEC_DIR/termy-spec-highlighter.zsh"
        fi
        # F-1/FB-1: register the publish hook LAST so it runs after z-s-h has
        # populated region_highlight for the current redraw (otherwise the live
        # coloring would lag one keystroke behind).
        add-zle-hook-widget zle-line-pre-redraw termy_buffer_publish
        """
    }
}
