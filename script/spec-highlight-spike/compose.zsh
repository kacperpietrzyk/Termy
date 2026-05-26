#!/usr/bin/env zsh
# compose.zsh — Task 4 of spec-highlight-spike
#
# Proves GATE 3 (z-s-h composition) and GATE 4 (lazy-load + cache).
#
# Usage:
#   zsh compose.zsh '<command line>'           # composed region_highlight dump
#   zsh compose.zsh --lazydemo '<command line>' # lazy-load proof: classify twice, show sourced-once
#
# The termy_spec custom highlighter is registered as name "termy_spec" so that:
#   ZSH_HIGHLIGHT_HIGHLIGHTERS=(main termy_spec)
# matches the function suffixes exactly.

# ---- Script dir ----------------------------------------------------------------
typeset -g _COMPOSE_DIR="${0:A:h}"

# ---- Source matcher (guard: only runs entry-point when ZSH_EVAL_CONTEXT==toplevel) ----
source "${_COMPOSE_DIR}/matcher.zsh"

# ---- Source vendored z-s-h -----------------------------------------------------
# Point HIGHLIGHTERS_DIR to vendor so z-s-h can load its own main highlighter.
ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR="${_COMPOSE_DIR}/../../vendor/zsh-syntax-highlighting/highlighters"
source "${_COMPOSE_DIR}/../../vendor/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# ---- Register ZSH_HIGHLIGHT_STYLES for termy_spec roles -------------------------
# _zsh_highlight_add_highlight looks up ZSH_HIGHLIGHT_STYLES[$key]; we populate
# the keys we use so it won't silently drop our entries. (We also append directly
# as a fallback since we don't rely on _zsh_highlight_add_highlight here.)
ZSH_HIGHLIGHT_STYLES[termy_spec:command]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[termy_spec:subcommand]='fg=cyan'
ZSH_HIGHLIGHT_STYLES[termy_spec:option]='fg=242'
ZSH_HIGHLIGHT_STYLES[termy_spec:option-argument]='fg=default'
ZSH_HIGHLIGHT_STYLES[termy_spec:argument]='fg=default'
ZSH_HIGHLIGHT_STYLES[termy_spec:error]='fg=red,bold'

# ---- termy_spec custom highlighter (z-s-h 0.5.0+ API) -------------------------

_zsh_highlight_highlighter_termy_spec_predicate() {
  # Always run for the probe (buffer-modified check is main's concern).
  return 0
}

_zsh_highlight_highlighter_termy_spec_paint() {
  # region_highlight uses 0-based half-open [start,end) offsets — same as matcher.
  # We avoid $(...) command substitution (which forks a subshell) so that the
  # _TS_LOADED cache guard persists back to the parent shell after this call.
  local line="$BUFFER"

  # Write classifier output to a temp file to avoid the subshell of $(...).
  local tmpfile
  tmpfile="$(mktemp /tmp/termy_spec_XXXXXX)"
  termy_spec_classify "$line" > "$tmpfile"

  [[ ! -s "$tmpfile" ]] && { rm -f "$tmpfile"; return; }

  local start end role style
  while IFS=' ' read -r start end role; do
    [[ -z "$role" ]] && continue
    case "$role" in
      command)         style='fg=green,bold' ;;
      subcommand)      style='fg=cyan' ;;
      option)          style='fg=242' ;;
      error)           style='fg=red,bold' ;;
      # option-argument / argument map to foreground-default in §6. Emit NOTHING
      # for them: region_highlight is last-entry-wins, and an explicit
      # fg=default appended after main would clobber main's string/path styling
      # (e.g. the yellow on "hello", the underline on /tmp). Skipping lets main
      # alone own those cells.
      option-argument|argument) continue ;;
      *)               continue ;;
    esac
    region_highlight+=("$start $end $style, memo=zsh-syntax-highlighting")
  done < "$tmpfile"
  rm -f "$tmpfile"
}

# ---- Configure highlighter list: main first, termy_spec second -----------------
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main termy_spec)

# ---- Headless probe helpers ----------------------------------------------------

_run_highlight() {
  local buf="$1"
  BUFFER="$buf"
  CURSOR=${#BUFFER}
  PENDING=0
  KEYS_QUEUED_COUNT=0
  # Seed region_highlight so z-s-h's existence check passes on empty arrays.
  # The cleanup at the top of _zsh_highlight removes memo-tagged entries before
  # running highlighters, so this sentinel is harmless.
  region_highlight=("0 0 fg=default, memo=zsh-syntax-highlighting")
  # Clear prior-buffer so main's predicate sees a change and runs.
  typeset -g _ZSH_HIGHLIGHT_PRIOR_BUFFER=

  _zsh_highlight
}

# ---- Lazy-load demo ------------------------------------------------------------

_lazydemo() {
  local buf="$1"
  print "=== Lazy-load proof: two classifications of '${buf}' ==="
  print "(debug output from [spec] sourcing goes to stderr)\n"

  export _TS_DEBUG_LOAD=1

  # First classification (via highlight run)
  _run_highlight "$buf"

  # Second classification (direct call — no ZLE context needed)
  termy_spec_classify "$buf" > /dev/null

  print "\nOnly ONE '[spec] sourcing git' line should appear above (on stderr)."
  print "(If two appear, the cache guard is broken.)"
}

# ---- Main entry point ----------------------------------------------------------

if [[ "$ZSH_EVAL_CONTEXT" == "toplevel" ]]; then
  if (( $# == 0 )); then
    print "Usage: zsh compose.zsh '<command line>'" >&2
    print "       zsh compose.zsh --lazydemo '<command line>'" >&2
    exit 1
  fi

  if [[ "$1" == "--lazydemo" ]]; then
    shift
    _lazydemo "${1:-git commit -m \"hello\" --amend /tmp}"
    exit 0
  fi

  # Normal mode: run composed highlight and dump region_highlight.
  _run_highlight "$1"

  print "=== region_highlight for: $1 ==="
  local entry
  for entry in "${region_highlight[@]}"; do
    print "  $entry"
  done
fi
