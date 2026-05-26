# termy-spec-highlighter.zsh — command-spec-aware syntax highlighter for Termy
#
# This file is source'd at runtime from $TERMY_SPEC_DIR/../ and registers the
# "termy_spec" custom highlighter for zsh-syntax-highlighting (0.5.0+ API).
#
# Highlighter name: termy_spec
# Required paint fn:     _zsh_highlight_highlighter_termy_spec_paint
# Required predicate fn: _zsh_highlight_highlighter_termy_spec_predicate
#
# Runtime contract (set by Swift / shell-integration script before sourcing):
#   TERMY_SPEC_DIR    — path to directory containing spec_<cmd>.zsh files
#   TERMY_SPEC_STYLES — assoc array keyed by role (command/subcommand/option/error)
#                       Roles option-argument/argument intentionally absent → skipped in paint.
#
# Roles emitted by the classifier:
#   command | subcommand | option | option-argument | argument | error
#
# Offsets: 0-based half-open [start, end)

# ---- Session cache -------------------------------------------------------
# Keyed by cmd name; value = 1 once the spec has been sourced.
typeset -gA _TS_LOADED

# ---- Result array --------------------------------------------------------
# termy_spec_classify writes triples "start end role" here (NO stdout).
# Paint hook reads directly — no subshell, so _TS_LOADED cache is preserved.
typeset -ga _TS_RESULT

# ---- Lazy spec loader ----------------------------------------------------
_ts_load_spec() {
  local cmd="$1"
  if [[ -z "${_TS_LOADED[$cmd]}" ]]; then
    local specfile="${TERMY_SPEC_DIR}/spec_${cmd}.zsh"
    if [[ -f "$specfile" ]]; then
      [[ -n "$_TS_DEBUG_LOAD" ]] && print -u2 "[spec] sourcing $cmd"
      source "$specfile"
    fi
    # Set unconditionally — this intentionally also caches "no spec for this
    # command" for the session, so a missing spec is not re-stat'd on every
    # keystroke. The bundled DB does not change at runtime.
    _TS_LOADED[$cmd]=1
  fi
}

# ---- Membership helpers (indirection via ${(P)}) -------------------------

# _ts_has_key varname word  → 0 if word is a key in the named assoc array
_ts_has_key() {
  local varname="$1" word="$2"
  local ref="${varname}[${word}]"
  local val="${(P)ref}"
  [[ -n "$val" ]]
}

# NOTE: option "takes-arg" lookups are inlined at each call site via ${(P)} —
# we deliberately do NOT factor them into a helper that prints to stdout, because
# capturing it ($(...)) would fork a subshell per option per redraw (the hot path
# runs on every keystroke). Inline indirect expansion forks nothing.

# _ts_prefix_match varname prefix  → 0 if any key starts with prefix
_ts_prefix_match() {
  local varname="$1" prefix="$2"
  # Guard: an UNDEFINED assoc var makes ${(@kP)} yield a spurious one-element
  # array holding the empty string, which an empty prefix would falsely match.
  # Bail out unless varname names an actual association.
  [[ "${(Pt)varname}" == *association* ]] || return 1
  local -a keys=( "${(@kP)varname}" )
  local k
  for k in "${keys[@]}"; do
    [[ "$k" == "${prefix}"* ]] && return 0
  done
  return 1
}

# ---- Core classifier -----------------------------------------------------
#
# termy_spec_classify <line>
#   Fills _TS_RESULT with "start end role" triples (0-based half-open).
#   Does NOT print anything to stdout. _TS_LOADED cache is preserved.

termy_spec_classify() {
  local line="$1"

  # Reset global result.
  _TS_RESULT=()

  # Detect trailing whitespace BEFORE ${(z)} eats it.
  local has_trailing_ws=0
  [[ "$line" == *[[:space:]] ]] && has_trailing_ws=1

  # Shell-word split (respects quoting).
  local -a words=( "${(z)line}" )
  local n=${#words}
  (( n == 0 )) && return

  # ---- Word-0: command gate ----
  local cmd="${words[1]}"
  local specfile="${TERMY_SPEC_DIR}/spec_${cmd}.zsh"

  # If no spec file AND command not in $commands (PATH executables), leave empty.
  if [[ ! -f "$specfile" ]] && (( ! ${+commands[$cmd]} )); then
    return
  fi

  # ---- Spec loading ----
  _ts_load_spec "$cmd"

  local cmd_upper="${cmd:u}"
  # sanitize: non-alphanumeric → _
  cmd_upper="${cmd_upper//[^A-Za-z0-9]/_}"

  # ---- Compute per-word offsets (0-based) ----
  local -a wstart=()
  local -a wend=()
  local pos=0
  local linelen=${#line}
  local i
  for (( i = 1; i <= n; i++ )); do
    local tok="${words[$i]}"
    # Skip whitespace to find token start
    while (( pos < linelen )) && [[ "${line[pos+1]}" == [[:space:]] ]]; do
      (( pos++ ))
    done
    wstart[$i]=$pos
    (( pos += ${#tok} ))
    wend[$i]=$pos
  done

  # Word 0 is always the command.
  _TS_RESULT+=( "${wstart[1]} ${wend[1]} command" )

  # varPrefix starts at TS_<CMD> and descends as subcommands are matched.
  local varPrefix="TS_${cmd_upper}"
  local widx=2          # next word index (1-based)
  local past_subcommands=0

  # ---- Specless / no-grammar fail-open (spec §6 / §7) ----
  # If no top-level grammar was loaded for this command — i.e. NEITHER
  # TS_<CMD>_SUB NOR TS_<CMD>_OPT is an association — we have no rules to
  # validate against. This covers both a command that is only on PATH (no spec
  # file, e.g. `ls`) and a degenerate empty spec file (e.g. `nano`/`rails`).
  # We must NOT run the option/validation parser, or every -flag would wrongly
  # turn red. Paint word-0 as command (green) and emit the rest as argument
  # (paint-skipped, so main keeps those cells). Then return.
  # (Note: many spec'd commands like `docker` define _SUB but no top-level _OPT;
  # the OR keeps those on full classification.)
  local top_sub_var_name="${varPrefix}_SUB"
  local top_opt_var_name="${varPrefix}_OPT"
  if [[ "${(Pt)top_sub_var_name}" != *association* \
     && "${(Pt)top_opt_var_name}" != *association* ]]; then
    local j
    for (( j = 2; j <= n; j++ )); do
      _TS_RESULT+=( "${wstart[$j]} ${wend[$j]} argument" )
    done
    return
  fi

  # ---- Subcommand descent (with two-pass global-option handling) ----

  while (( widx <= n && ! past_subcommands )); do
    local w="${words[$widx]}"
    local sub_var="${varPrefix}_SUB"

    # Does sub_var exist at all? Type-check via ${(Pt)}: an UNDEFINED variable
    # yields the empty string (not "association"), whereas ${(@kP)} on an
    # undefined var returns a spurious one-element array (the empty string) —
    # so an element-count test ${#...}==0 would never fire and descent would
    # wrongly continue, mis-classifying positional args as trailing-prefix errors.
    if [[ "${(Pt)sub_var}" != *association* ]]; then
      # No subcommand table at this level — stop descending.
      past_subcommands=1
      break
    fi

    # Option token at current level? — two-pass: try to consume as a known global option.
    if [[ "$w" == -* && "$w" != "--" ]]; then
      local top_opt_var="${varPrefix}_OPT"
      if _ts_has_key "$top_opt_var" "$w"; then
        # Known option at this level — classify and potentially consume its argument.
        _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} option" )
        local takes_ref="${top_opt_var}[$w]"
        local takes="${(P)takes_ref}"
        (( widx++ ))
        if [[ "$takes" == "1" ]] && (( widx <= n )); then
          _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} option-argument" )
          (( widx++ ))
        fi
        # Stay in descent loop — the next word may still be the subcommand.
        continue
      fi
      # Unknown option at top level — fall through to option-parser.
      past_subcommands=1
      break
    fi

    # Bare -- separator → break; option-parser will classify it as argument.
    if [[ "$w" == "--" ]]; then
      past_subcommands=1
      break
    fi

    # Is this word the trailing (cursor) token?
    local is_trailing=0
    (( widx == n && has_trailing_ws == 0 )) && is_trailing=1

    if _ts_has_key "$sub_var" "$w"; then
      # Exact match — it's a subcommand; descend.
      _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} subcommand" )
      # Build next varPrefix: sanitize word for var name.
      local sanitized="${w//[^A-Za-z0-9]/_}"
      varPrefix="${varPrefix}_${sanitized}"
      (( widx++ ))
    elif (( is_trailing )); then
      # Trailing partial: lenient — only error if not a prefix of any SUB key.
      if _ts_prefix_match "$sub_var" "$w"; then
        _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} subcommand" )
      else
        _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} error" )
      fi
      (( widx++ ))
      past_subcommands=1
    else
      # Completed, not matched → stop descending; treat remaining as options/args.
      past_subcommands=1
    fi
  done

  # ---- Option / argument parsing (after subcommand descent) ----
  local opt_var="${varPrefix}_OPT"
  local expect_optarg=0   # 1 when previous option takes an argument
  local after_dashdash=0  # 1 after bare --

  while (( widx <= n )); do
    local w="${words[$widx]}"
    local is_trailing=0
    (( widx == n && has_trailing_ws == 0 )) && is_trailing=1

    if (( after_dashdash )); then
      _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} argument" )
      (( widx++ ))
      continue
    fi

    if (( expect_optarg )); then
      _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} option-argument" )
      expect_optarg=0
      (( widx++ ))
      continue
    fi

    # Bare -- → all remaining tokens are positional arguments.
    if [[ "$w" == "--" ]]; then
      _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} argument" )
      after_dashdash=1
      (( widx++ ))
      continue
    fi

    # Option token?
    if [[ "$w" == -* ]]; then
      # --long=val  → entire token is classified as option (value is inline).
      if [[ "$w" == --*=* ]]; then
        local flag="${w%%=*}"
        if _ts_has_key "$opt_var" "$flag"; then
          _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} option" )
        elif (( is_trailing )) && _ts_prefix_match "$opt_var" "$flag"; then
          _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} option" )
        else
          _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} error" )
        fi
        # No expect_optarg — value is inline.
        (( widx++ ))
        continue
      fi

      # Long option --flag
      if [[ "$w" == --* ]]; then
        if _ts_has_key "$opt_var" "$w"; then
          _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} option" )
          local takes_ref="${opt_var}[$w]"
          local takes="${(P)takes_ref}"
          [[ "$takes" == "1" ]] && expect_optarg=1
        elif (( is_trailing )) && _ts_prefix_match "$opt_var" "$w"; then
          _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} option" )
        else
          _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} error" )
        fi
        (( widx++ ))
        continue
      fi

      # Short option -x or bundled -abc.
      # First check if the whole token is a known key (handles -C, -m, etc.)
      if _ts_has_key "$opt_var" "$w"; then
        _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} option" )
        local takes_ref="${opt_var}[$w]"
        local takes="${(P)takes_ref}"
        [[ "$takes" == "1" ]] && expect_optarg=1
      elif (( is_trailing )) && _ts_prefix_match "$opt_var" "$w"; then
        _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} option" )
      else
        # Try bundled short options (-abc where each -x is separately known).
        local bundled_ok=1
        local chars="${w#-}"
        local ci
        for (( ci = 1; ci <= ${#chars}; ci++ )); do
          local ch="${chars[$ci]}"
          if ! _ts_has_key "$opt_var" "-${ch}"; then
            bundled_ok=0
            break
          fi
        done
        if (( bundled_ok )); then
          _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} option" )
        else
          _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} error" )
        fi
      fi
      (( widx++ ))
      continue
    fi

    # Not an option and not after -- → positional argument.
    _TS_RESULT+=( "${wstart[$widx]} ${wend[$widx]} argument" )
    (( widx++ ))
  done
}

# ---- z-s-h highlighter hooks ---------------------------------------------

# _zsh_highlight_highlighter_termy_spec_predicate
#   Called by z-s-h to decide whether to run our paint hook.
#   Always return 0 (run on every buffer change).
_zsh_highlight_highlighter_termy_spec_predicate() {
  return 0
}

# _zsh_highlight_highlighter_termy_spec_paint
#   Called by z-s-h to apply highlights to region_highlight.
#   Reads _TS_RESULT directly — no $() subshell — so _TS_LOADED cache persists.
#   Only appends entries for roles present in TERMY_SPEC_STYLES;
#   option-argument and argument are skipped (no key → fg=default, let main own them).
_zsh_highlight_highlighter_termy_spec_paint() {
  termy_spec_classify "$BUFFER"
  local triple start end role rest
  for triple in "${_TS_RESULT[@]}"; do
    start="${triple%% *}"
    rest="${triple#* }"
    end="${rest%% *}"
    role="${rest#* }"
    # Skip roles that have no style entry (option-argument, argument).
    [[ -z "${TERMY_SPEC_STYLES[$role]}" ]] && continue
    region_highlight+=( "$start $end ${TERMY_SPEC_STYLES[$role]}, memo=zsh-syntax-highlighting" )
  done
}
