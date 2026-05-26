#!/usr/bin/env zsh
# matcher.zsh — spec-aware command-line classifier (Task 3 of spec-highlight-spike)
#
# Usage:  zsh matcher.zsh '<command line>'
# Output: one triple per token  "start end role"  (0-based byte offsets, [start,end) half-open)
# Roles:  command | subcommand | option | option-argument | argument | error
#
# Validation rule (settles §6 ambiguity):
#   A completed token (not the trailing/cursor token) is validated strictly:
#   unknown subcmd or option → error.
#   The trailing token (input has NO trailing space) is lenient:
#   error only when it cannot be a valid prefix of ANY expected token at its position.

# ---- Script directory (captured at top level before any function calls) ------
# ${0:A:h} works here at the script's top scope; inside functions $0 = funcname.
typeset -g _TS_SCRIPT_DIR="${0:A:h}"

# ---- Lazy spec loader --------------------------------------------------------
# Session cache: keyed by cmd name; value = 1 once sourced.
typeset -gA _TS_LOADED

_ts_load_spec() {
  local cmd="$1"
  if [[ -z "${_TS_LOADED[$cmd]}" ]]; then
    local specfile="${_TS_SCRIPT_DIR}/out/spec_${cmd}.zsh"
    if [[ -f "$specfile" ]]; then
      [[ -n "$_TS_DEBUG_LOAD" ]] && print -u2 "[spec] sourcing $cmd"
      source "$specfile"
    fi
    _TS_LOADED[$cmd]=1
  fi
}

# ---- Membership helpers (indirection via ${(P)}) ----------------------------

# _ts_has_key varname word
#   Return 0 if word is an exact key in the named associative array.
_ts_has_key() {
  local varname="$1" word="$2"
  local ref="${varname}[${word}]"
  local val="${(P)ref}"
  # values are "0" or "1" — never empty; unset key = empty string
  [[ -n "$val" ]]
}

# _ts_key_value varname word  (prints value)
_ts_key_value() {
  local varname="$1" word="$2"
  local ref="${varname}[${word}]"
  printf '%s' "${(P)ref}"
}

# _ts_prefix_match varname prefix
#   Return 0 if any key in the named assoc array starts with prefix.
_ts_prefix_match() {
  local varname="$1" prefix="$2"
  local -a keys=( "${(@kP)varname}" )
  local k
  for k in "${keys[@]}"; do
    [[ "$k" == "${prefix}"* ]] && return 0
  done
  return 1
}

# ---- Core classifier ---------------------------------------------------------

termy_spec_classify() {
  local line="$1"

  # Detect trailing whitespace BEFORE ${(z)} eats it.
  local has_trailing_ws=0
  [[ "$line" == *[[:space:]] ]] && has_trailing_ws=1

  # Shell-word split (respects quoting).
  local -a words=( "${(z)line}" )
  local n=${#words}
  (( n == 0 )) && return

  # Output array: each element = "start end role"
  local -a out=()

  # --- Parallel offset walk ---
  # zsh strings are 1-based; we track pos as 0-based byte offset into line.
  local pos=0
  local linelen=${#line}

  # Compute per-word offsets.
  local -a wstart=()
  local -a wend=()
  local i
  for (( i = 1; i <= n; i++ )); do
    local tok="${words[$i]}"
    # Skip whitespace
    while (( pos < linelen )) && [[ "${line[pos+1]}" == [[:space:]] ]]; do
      (( pos++ ))
    done
    wstart[$i]=$pos
    (( pos += ${#tok} ))
    wend[$i]=$pos
  done

  # ---- Spec loading ----
  local cmd="${words[1]}"
  _ts_load_spec "$cmd"

  local cmd_upper="${cmd:u}"
  # sanitize: non-alphanumeric → _
  cmd_upper="${cmd_upper//[^A-Za-z0-9]/_}"

  # Word 0 is always the command.
  out+=( "${wstart[1]} ${wend[1]} command" )

  # ---- Subcommand descent ----
  # varPrefix starts at TS_<CMD> and we descend as long as SUB matches.
  local varPrefix="TS_${cmd_upper}"
  local widx=2          # next word to consume
  local past_subcommands=0

  while (( widx <= n && ! past_subcommands )); do
    local w="${words[$widx]}"
    local sub_var="${varPrefix}_SUB"
    # Does sub_var exist at all?
    local -a sub_keys=( "${(@kP)sub_var}" )
    if (( ${#sub_keys} == 0 )); then
      # No subcommand table at this level — stop descending.
      past_subcommands=1
      break
    fi
    # Is this word an option (starts with -)?
    if [[ "$w" == -* ]]; then
      past_subcommands=1
      break
    fi
    # Is it `--` separator?
    if [[ "$w" == "--" ]]; then
      past_subcommands=1
      break
    fi

    # Check if this word is the trailing (cursor) token.
    local is_trailing=0
    (( widx == n && has_trailing_ws == 0 )) && is_trailing=1

    if _ts_has_key "$sub_var" "$w"; then
      # Exact match — it's a subcommand; descend.
      out+=( "${wstart[$widx]} ${wend[$widx]} subcommand" )
      # Build next varPrefix: sanitize word for var name
      local sanitized="${w//[^A-Za-z0-9]/_}"
      varPrefix="${varPrefix}_${sanitized}"
      (( widx++ ))
    elif (( is_trailing )); then
      # Trailing partial: lenient — only error if not a prefix of any SUB key.
      if _ts_prefix_match "$sub_var" "$w"; then
        out+=( "${wstart[$widx]} ${wend[$widx]} subcommand" )
      else
        out+=( "${wstart[$widx]} ${wend[$widx]} error" )
      fi
      (( widx++ ))
      past_subcommands=1
    else
      # Completed, not matched → stop descending; treat as positional/option.
      past_subcommands=1
    fi
  done

  # ---- Option / argument parsing ----
  local opt_var="${varPrefix}_OPT"
  local expect_optarg=0     # 1 when previous option takes an arg
  local after_dashdash=0    # 1 after bare --

  while (( widx <= n )); do
    local w="${words[$widx]}"
    local is_trailing=0
    (( widx == n && has_trailing_ws == 0 )) && is_trailing=1

    if (( after_dashdash )); then
      out+=( "${wstart[$widx]} ${wend[$widx]} argument" )
      (( widx++ ))
      continue
    fi

    if (( expect_optarg )); then
      out+=( "${wstart[$widx]} ${wend[$widx]} option-argument" )
      expect_optarg=0
      (( widx++ ))
      continue
    fi

    # Bare -- → rest are positional
    if [[ "$w" == "--" ]]; then
      out+=( "${wstart[$widx]} ${wend[$widx]} argument" )
      after_dashdash=1
      (( widx++ ))
      continue
    fi

    # Option token?
    if [[ "$w" == -* ]]; then
      # --long=val  → split inline
      if [[ "$w" == --*=* ]]; then
        # The whole "word" from ${(z)} will be --flag=val as one token.
        # Classify as option; the =val part is inline option-argument (no separate token).
        # For simplicity: classify the entire token as option if --flag is known.
        local flag="${w%%=*}"
        if _ts_has_key "$opt_var" "$flag"; then
          out+=( "${wstart[$widx]} ${wend[$widx]} option" )
        elif (( is_trailing )) && _ts_prefix_match "$opt_var" "$flag"; then
          out+=( "${wstart[$widx]} ${wend[$widx]} option" )
        else
          out+=( "${wstart[$widx]} ${wend[$widx]} error" )
        fi
        # No expect_optarg — value is inline.
        expect_optarg=0
        (( widx++ ))
        continue
      fi

      # Long option --flag
      if [[ "$w" == --* ]]; then
        if _ts_has_key "$opt_var" "$w"; then
          out+=( "${wstart[$widx]} ${wend[$widx]} option" )
          local takes="$(_ts_key_value "$opt_var" "$w")"
          [[ "$takes" == "1" ]] && expect_optarg=1
        elif (( is_trailing )) && _ts_prefix_match "$opt_var" "$w"; then
          out+=( "${wstart[$widx]} ${wend[$widx]} option" )
        else
          out+=( "${wstart[$widx]} ${wend[$widx]} error" )
        fi
        (( widx++ ))
        continue
      fi

      # Short option -x or bundled -abc
      # First check if the whole token is a known key (handles -C, -m, etc.)
      if _ts_has_key "$opt_var" "$w"; then
        out+=( "${wstart[$widx]} ${wend[$widx]} option" )
        local takes="$(_ts_key_value "$opt_var" "$w")"
        [[ "$takes" == "1" ]] && expect_optarg=1
      elif (( is_trailing )) && _ts_prefix_match "$opt_var" "$w"; then
        out+=( "${wstart[$widx]} ${wend[$widx]} option" )
      else
        # Could be bundled (-abc): each char after - is a separate flag.
        # For the prototype, classify as error if not an exact match and not trailing-prefix.
        # (Production would expand bundled flags; out of scope here.)
        # Actually: try each char as a separate short option key "-x".
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
          out+=( "${wstart[$widx]} ${wend[$widx]} option" )
        else
          out+=( "${wstart[$widx]} ${wend[$widx]} error" )
        fi
      fi
      (( widx++ ))
      continue
    fi

    # Not an option and not after -- → positional argument.
    out+=( "${wstart[$widx]} ${wend[$widx]} argument" )
    (( widx++ ))
  done

  # Print results.
  local triple
  for triple in "${out[@]}"; do
    print -- "$triple"
  done
}

# ---- Script entry point -------------------------------------------------------
# When run as a script (not sourced), classify the first argument.
# ZSH_EVAL_CONTEXT is "toplevel" when run directly, contains ":file" when sourced.
if [[ "$ZSH_EVAL_CONTEXT" == "toplevel" ]]; then
  if (( $# == 0 )); then
    print "Usage: zsh matcher.zsh '<command line>'" >&2
    exit 1
  fi
  termy_spec_classify "$1"
fi
