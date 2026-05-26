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
        termy_preexec() {
          printf '\\033]133;C;cmd=%s\\007' "$1"
        }
        termy_precmd() {
          local termy_status=$?
          printf '\\033]133;D;exit=%d;pwd=%s\\007' "$termy_status" "$PWD"
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
