import Foundation

/// Variant-A zsh script that the F-4 sidecar sources after the user's `.zshrc`.
///
/// Post-spike (commit `d0ad6b5`) design:
///   • Function-shadows `compadd` to capture every completion candidate.
///     (Alias-based shadowing fails — aliases don't intercept builtins called
///     from inside compsys `_*` functions.)
///   • Defines `_termy_capture` as a **completion widget** (`zle -C`),
///     NOT a generic widget (`zle -N`). Only `-C` gives `_main_complete` the
///     `compstate`/`words`/`PREFIX`/`SUFFIX` context it needs.
///   • Runs `_main_complete` inside zle, captures via the shadow, atomically
///     publishes results as TSV at `$TERMY_SIDECAR_DIR/req-<id>.tsv`.
///   • Boot handshake = empty `$TERMY_SIDECAR_DIR/__boot__.flag` (the
///     parent watches the dir with DispatchSource).
///   • Defensive `compinit` because plugin managers (oh-my-zsh, znap, etc.)
///     defer it from the user's `.zshrc`.
///   • Defensive `_zsh_autosuggest_disable` so the user's autosuggestions
///     plugin (if loaded) doesn't race the widget.
public enum SidecarShellScript {
    public static let template: String = #"""
# F-4 sidecar bootstrap — sourced inside `zsh -i` AFTER user .zshrc.
emulate -L zsh
setopt LOCAL_OPTIONS NO_ERR_RETURN NO_ERR_EXIT

# Defensive compinit — user .zshrc may defer it through a plugin manager.
if (( ${+_comps[git]} == 0 )); then
  autoload -Uz compinit && compinit -u 2>/dev/null
fi
_zsh_autosuggest_disable 2>/dev/null

typeset -ga __termy_captured
typeset -g __termy_req_id=""
typeset -g __termy_cwd=""
typeset -g __termy_cd_target=""

# ------------------------------------------------------------------
# compadd function shadow.
# ------------------------------------------------------------------
# Walks compadd's argv looking for the description array (`-d <name>`)
# and the candidate words. Emits one TSV line per candidate to the
# per-request global array. ALWAYS delegates to the real builtin so
# zsh completion state stays consistent for subsequent compsys calls.
function compadd {
  local -a __t_titles __t_descs __t_matched __t_order_values
  local __t_desc_var="" __t_kind="commands" __t_i=1 __t_should_capture=1 __t_array_mode=""
  if [[ -n "${curtag:-}" ]]; then __t_kind="$curtag"; fi
  __t_order_values=(match mat ma nosort nos no numeric num nu reverse rev re)

  while (( __t_i <= $# )); do
    case "${(P)__t_i}" in
      -d)  (( __t_i++ )); __t_desc_var="${(P)__t_i}" ;;
      -ld|-dl) (( __t_i++ )); __t_desc_var="${(P)__t_i}" ;;
      -a)  __t_array_mode="array" ;;
      -k)  __t_array_mode="assoc" ;;
      # zsh 5.9 zshcompwid(1): compadd flags that consume one argument.
      -P|-S|-p|-s|-i|-I|-W|-J|-X|-x|-V|-r|-R|-F|-M|-E)
           (( __t_i++ )) ;;
      # These options store/filter matches in caller-provided arrays and do
      # not add user-visible matches themselves.
      -O|-A|-D)
           __t_should_capture=0
           (( __t_i++ )) ;;
      -o)
           # Optional order value. Consume only documented order tokens so
           # `compadd -o nosort ...` doesn't leak "nosort" as a candidate,
           # while bare `-o` still leaves following completions intact.
           if (( __t_i < $# )); then
             local __t_next_i=$(( __t_i + 1 ))
             local __t_next="${(P)__t_next_i}"
             local -a __t_order_parts
             __t_order_parts=("${(@s:,:)__t_next}")
             local __t_order_ok=1 __t_order_part
             for __t_order_part in "${__t_order_parts[@]}"; do
               if (( ${__t_order_values[(Ie)$__t_order_part]} == 0 )); then
                 __t_order_ok=0
                 break
               fi
             done
             if (( __t_order_ok && ${#__t_order_parts} > 0 )); then
               (( __t_i++ ))
             fi
           fi ;;
      --)  (( __t_i++ )); break ;;
      -)   (( __t_i++ )); break ;;
      -*)  ;;
      *)   __t_titles+=("${(P)__t_i}") ;;
    esac
    (( __t_i++ ))
  done
  while (( __t_i <= $# )); do
    __t_titles+=("${(P)__t_i}")
    (( __t_i++ ))
  done
  if [[ -n "$__t_array_mode" ]]; then
    local -a __t_expanded_titles __t_values
    local __t_ref
    for __t_ref in "${__t_titles[@]}"; do
      __t_values=()
      if [[ "$__t_array_mode" == "assoc" ]]; then
        eval "__t_values=(\"\${(@k)${__t_ref}}\")" 2>/dev/null
      else
        eval "__t_values=(\"\${${__t_ref}[@]}\")" 2>/dev/null
      fi
      __t_expanded_titles+=("${__t_values[@]}")
    done
    __t_titles=("${__t_expanded_titles[@]}")
  fi
  if [[ -n "$__t_desc_var" ]]; then
    eval "__t_descs=(\"\${${__t_desc_var}[@]}\")"
  fi
  if (( __t_should_capture )); then
    builtin compadd -O __t_matched "$@" 2>/dev/null
  fi

  local __t_n=${#__t_matched} __t_j=1
  while (( __t_j <= __t_n )); do
    local __t_title="${__t_matched[__t_j]}"
    local __t_desc=""
    local __t_original_i=1
    while (( __t_original_i <= ${#__t_titles} )); do
      [[ "${__t_titles[__t_original_i]}" == "$__t_title" ]] && break
      (( __t_original_i++ ))
    done
    if (( __t_original_i <= ${#__t_descs} )); then
      __t_desc="${__t_descs[__t_original_i]}"
      # _describe formats entries as "title -- description"; strip prefix.
      __t_desc="${__t_desc#* -- }"
      [[ "$__t_desc" == "$__t_title" ]] && __t_desc=""
    fi
    # Strip embedded tabs/newlines from title/desc to keep TSV well-formed.
    __t_title="${__t_title//$'\t'/ }"; __t_title="${__t_title//$'\n'/ }"
    __t_desc="${__t_desc//$'\t'/ }";   __t_desc="${__t_desc//$'\n'/ }"
    __termy_captured+=("${__t_kind}	${__t_title}	${__t_title}	${__t_desc}")
    (( __t_j++ ))
  done
  builtin compadd "$@"
}

# ------------------------------------------------------------------
# Completion widget.
# ------------------------------------------------------------------
# MUST be registered with `zle -C` (completion widget) — `zle -N` leaves
# compstate/words/PREFIX/SUFFIX uninitialized and _main_complete returns
# zero candidates (spike finding #1).
function _termy_capture {
  local __t_req_file="${TERMY_SIDECAR_DIR}/__request__.tsv"
  if [[ -r "$__t_req_file" ]]; then
    local __t_req_line
    IFS= read -r __t_req_line < "$__t_req_file"
    __termy_req_id="${__t_req_line%%$'\t'*}"
    __termy_cwd="${__t_req_line#*$'\t'}"
    [[ "$__termy_cwd" == "$__t_req_line" ]] && __termy_cwd=""
  fi
  [[ -z "$__termy_req_id" ]] && return 0
  __termy_captured=()
  if [[ -n "$__termy_cwd" ]]; then cd -- "$__termy_cwd" 2>/dev/null; fi
  _main_complete 2>/dev/null
  # Cap at 100 (spec §7.8).
  if (( ${#__termy_captured} > 100 )); then
    __termy_captured=("${__termy_captured[@]:0:100}")
  fi
  # Atomic publish: write to .tsv.tmp then mv -f rename to final.
  local __t_tmp="${TERMY_SIDECAR_DIR}/req-${__termy_req_id}.tsv.tmp"
  local __t_fin="${TERMY_SIDECAR_DIR}/req-${__termy_req_id}.tsv"
  if (( ${#__termy_captured} > 0 )); then
    printf '%s\n' "${__termy_captured[@]}" > "$__t_tmp"
  else
    : > "$__t_tmp"
  fi
  mv -f "$__t_tmp" "$__t_fin" 2>/dev/null
}
zle -C _termy_capture .complete-word _termy_capture
bindkey '\eq' _termy_capture

# ------------------------------------------------------------------
# cd op-code (no result file).
# ------------------------------------------------------------------
function _termy_cd { cd -- "$__termy_cd_target" 2>/dev/null }

# ------------------------------------------------------------------
# Boot handshake — empty flag file; parent's DispatchSource picks it up.
# ------------------------------------------------------------------
if [[ -n "$TERMY_SIDECAR_DIR" ]]; then
  : > "${TERMY_SIDECAR_DIR}/__boot__.flag"
fi
"""#
}
