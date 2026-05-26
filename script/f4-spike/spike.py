#!/usr/bin/env python3
"""
F-4 §0 spike — proves Variant A mechanism on this machine.

Uses pty.fork() to give zsh a real PTY so zle starts, installs the
compadd function shadow + __termy_complete_widget registered as a
completion widget (zle -C) bound to ^X^T, and drives queries through
the same persistent shell process.

Results are delivered via a temp file, not PTY stdout, to avoid
terminal-display race conditions.

Exit 0 on PASS; non-zero on FAIL.
"""

import os
import pty
import sys
import time
import select
import termios
import struct
import fcntl
import signal
import re
import tempfile

ZSH = "/bin/zsh"
TRIGGER = b"\x18\x14"       # ^X^T
TIMEOUT_S = 12.0            # per-query read timeout

# Result file that the widget writes to; Python reads after each query.
RESULT_FILE = "/tmp/termy_spike_result.txt"
LOG_FILE = "/tmp/termy_spike.log"

SIDECAR_SCRIPT = r'''
# Defensive compinit: user .zshrc may not have called it.
if (( ${+_comps} == 0 )) || [[ -z "${_comps[git]:-}" ]]; then
  autoload -U compinit
  compinit -u 2>/dev/null
fi

typeset -ga __termy_captured
typeset -g __termy_req_id="__boot__"
typeset -g __termy_result_file="''' + RESULT_FILE + r'''"
typeset -g __termy_log_file="''' + LOG_FILE + r'''"

# Disable autosuggestions defensively — they may race with our widget
_zsh_autosuggest_disable 2>/dev/null

# Function shadow of compadd. NOT an alias: aliases don't intercept
# builtins called from inside compsys _* functions.
function compadd {
  local -a __t_titles __t_descs __t_matched __t_order_values
  local __t_desc_var="" __t_i=1 __t_should_capture=1 __t_array_mode=""
  __t_order_values=(match mat ma nosort nos no numeric num nu reverse rev re)
  while (( __t_i <= $# )); do
    case "${(P)__t_i}" in
      -d) (( __t_i++ )); __t_desc_var="${(P)__t_i}" ;;
      -ld|-dl) (( __t_i++ )); __t_desc_var="${(P)__t_i}" ;;
      -a) __t_array_mode="array" ;;
      -k) __t_array_mode="assoc" ;;
      -P|-S|-p|-s|-i|-I|-W|-J|-X|-x|-V|-r|-R|-F|-M|-E)
          (( __t_i++ )) ;;
      -O|-A|-D)
          __t_should_capture=0
          (( __t_i++ )) ;;
      -o)
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
      --) (( __t_i++ )); break ;;
      -)  (( __t_i++ )); break ;;
      -*) ;;
      *)  __t_titles+=("${(P)__t_i}") ;;
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
  local __t_n=${#__t_matched}
  for (( __t_j=1; __t_j<=__t_n; __t_j++ )); do
    local __t_title="${__t_matched[__t_j]}" __t_desc=""
    local __t_original_i=1
    while (( __t_original_i <= ${#__t_titles} )); do
      [[ "${__t_titles[__t_original_i]}" == "$__t_title" ]] && break
      (( __t_original_i++ ))
    done
    if (( __t_original_i <= ${#__t_descs} )); then
      __t_desc="${__t_descs[__t_original_i]}"
      __t_desc="${__t_desc#* -- }"
      [[ "$__t_desc" == "$__t_title" ]] && __t_desc=""
    fi
    __termy_captured+=("${__t_title}"$'\t'"${__t_desc}")
  done
  builtin compadd "$@"
}

# _termy_capture is the completion function registered with zle -C.
# It receives the same context as a normal completion widget
# (_main_complete has proper compstate/words/PREFIX/SUFFIX).
function _termy_capture {
  # Record widget state for spike assertions (file-based, no PTY display race)
  print -r -- "STATE	${__termy_req_id}	${BUFFER}	${CURSOR}	${PREFIX}	${(j: :)words}" >> "${__termy_log_file}"

  __termy_captured=()
  _main_complete 2>/dev/null || true

  local __t_n=${#__termy_captured}

  # Write results to file atomically via temp+rename
  local __t_tmp="${__termy_result_file}.tmp"
  {
    print -r -- "BEGIN ${__termy_req_id}"
    (( __t_n > 0 )) && printf '%s\n' "${__termy_captured[@]}"
    print -r -- "END ${__termy_req_id} n=${__t_n}"
  } > "${__t_tmp}"
  mv -f "${__t_tmp}" "${__termy_result_file}"

  # Clear the buffer and reset prompt
  BUFFER=""
  CURSOR=0
  zle .reset-prompt 2>/dev/null || true
}

# Register as a COMPLETION widget (zle -C), not a generic widget (zle -N).
# This gives _termy_capture the same context as a real Tab completion:
# compstate, words, PREFIX, SUFFIX are all properly initialized.
zle -C __termy_complete_widget complete-word _termy_capture
bindkey $'\x18\x14' __termy_complete_widget

# Clear log and result files
: > "${__termy_log_file}"
: > "${__termy_result_file}"

print -r -- "SIDECAR_READY"
'''


def set_winsize(fd, rows=24, cols=220):
    """Set terminal window size on the pty master."""
    s = struct.pack("HHHH", rows, cols, 0, 0)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, s)


def read_until(fd, sentinel, timeout=TIMEOUT_S, extra_stop=None):
    """
    Read bytes from fd until sentinel appears in the accumulated output.
    Returns (raw_bytes, clean_bytes). Strips ANSI escape sequences for
    sentinel matching but returns raw bytes for failure reporting.
    """
    buf = b""
    deadline = time.monotonic() + timeout
    ansi_escape = re.compile(rb"\x1b\[[0-9;]*[a-zA-Z]|\x1b\][^\x07]*\x07|\r")
    while time.monotonic() < deadline:
        remaining = deadline - time.monotonic()
        r, _, _ = select.select([fd], [], [], min(remaining, 0.1))
        if not r:
            continue
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            break
        if not chunk:
            break
        buf += chunk
        # Strip ANSI for matching
        clean = ansi_escape.sub(b"", buf)
        if sentinel in clean:
            return buf, clean
        if extra_stop and extra_stop in clean:
            return buf, clean
    return buf, ansi_escape.sub(b"", buf)


def send(fd, data: bytes):
    os.write(fd, data)


def spawn_zsh():
    """Fork a zsh with a real PTY and return (master_fd, pid)."""
    pid, master_fd = pty.fork()
    if pid == 0:
        # Child: exec zsh -i
        env = {
            "SHELL": ZSH,
            "PATH": os.environ.get("PATH", "/usr/bin:/bin:/usr/local/bin"),
            "HOME": os.environ.get("HOME", "/"),
            "TERM": "xterm-256color",
            "LANG": os.environ.get("LANG", "en_US.UTF-8"),
            "PROMPT": "",
            "RPROMPT": "",
            "HISTFILE": "/dev/null",
        }
        # Preserve ZDOTDIR if set, otherwise let zsh use the default (.zshrc)
        if "ZDOTDIR" in os.environ:
            env["ZDOTDIR"] = os.environ["ZDOTDIR"]
        os.execvpe(ZSH, [ZSH, "-i"], env)
        sys.exit(1)
    # Parent
    set_winsize(master_fd)
    return master_fd, pid


def boot_sidecar(master_fd, tmpfile_path):
    """Wait for zsh prompt then source the sidecar script from a temp file."""
    # Wait for zsh to initialize and source .zshrc
    time.sleep(1.5)
    # Drain startup output
    drain(master_fd, 0.3)

    # Disable bracketed paste mode
    send(master_fd, b"unset zle_bracketed_paste; printf '\\033[?2004l'\n")
    time.sleep(0.3)
    drain(master_fd, 0.1)

    # Source the sidecar script from the temp file path
    source_cmd = f"source {tmpfile_path}\n"
    send(master_fd, source_cmd.encode())

    # Wait for SIDECAR_READY
    raw, clean = read_until(master_fd, b"SIDECAR_READY", timeout=25.0)
    if b"SIDECAR_READY" not in clean:
        print(f"ERROR: sidecar did not print SIDECAR_READY.", file=sys.stderr)
        print(f"  raw output snippet: {clean[-600:]!r}", file=sys.stderr)
        return False

    # Drain remaining output after SIDECAR_READY
    time.sleep(0.3)
    drain(master_fd, 0.2)
    return True


def drain(master_fd, timeout=0.1):
    """Drain any pending output from the pty."""
    while True:
        r, _, _ = select.select([master_fd], [], [], timeout)
        if not r:
            break
        try:
            os.read(master_fd, 4096)
        except OSError:
            break


def wait_for_result_file(label, timeout=TIMEOUT_S):
    """
    Poll RESULT_FILE until it contains 'END {label}'.
    Returns list of (title, description) tuples, or None on timeout.
    """
    end_marker = f"END {label}"
    begin_marker = f"BEGIN {label}"
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with open(RESULT_FILE, "r", encoding="utf-8", errors="replace") as f:
                content = f.read()
            if end_marker in content:
                # Parse results — do NOT call line.strip() (the tab between title
                # and desc may be at end of line for empty-desc entries; strip()
                # would remove it and break the \t check)
                lines = content.splitlines()
                capturing = False
                results = []
                for line in lines:
                    line_stripped = line.rstrip("\r\n")  # strip only line endings
                    if line_stripped.startswith(begin_marker):
                        capturing = True
                        continue
                    if line_stripped.startswith(end_marker):
                        break
                    if capturing:
                        if "\t" in line_stripped:
                            parts = line_stripped.split("\t", 1)
                            title = parts[0].strip()
                            desc = parts[1].strip() if len(parts) > 1 else ""
                        else:
                            title = line_stripped.strip()
                            desc = ""
                        if title:
                            results.append((title, desc))
                return results
        except (FileNotFoundError, IOError):
            pass
        time.sleep(0.01)
    return None


def read_widget_state(label):
    """Return the widget STATE log row for label as (buffer, cursor, prefix)."""
    try:
        with open(LOG_FILE, "r", encoding="utf-8", errors="replace") as lf:
            rows = [line.rstrip("\n").split("\t") for line in lf]
    except OSError:
        return None
    for row in reversed(rows):
        if len(row) >= 5 and row[0] == "STATE" and row[1] == label:
            try:
                return row[2], int(row[3]), row[4]
            except ValueError:
                return None
    return None


def reset_zle_buffer(master_fd):
    """Send Ctrl-U to kill the current zle line, then drain."""
    send(master_fd, b"\x15")  # ^U = kill whole line
    time.sleep(0.05)
    drain(master_fd, 0.05)


def run_query(master_fd, label, buffer_text, cwd):
    """
    Run a completion query by:
    1. Resetting any stale buffer with ^U
    2. Executing setup commands (req_id + cd) as a real shell command
    3. Clearing the result file
    4. Typing buffer_text into the active zle prompt
    5. Sending ^X^T trigger to fire the widget
    6. Polling the result file for results

    Returns list of (title, description) tuples.
    """
    # Step 0: Kill any stale buffer content (^U = kill whole line)
    reset_zle_buffer(master_fd)

    # Step 1: Execute setup commands (cd + set req_id) as a real shell command
    setup_cmd = f"__termy_req_id={label!r}; cd {cwd!r}\n"
    send(master_fd, setup_cmd.encode())
    # Wait for prompt to reappear after the command
    time.sleep(0.25)
    drain(master_fd, 0.15)

    # Step 2: Kill any echoed text that might have accumulated from drain latency
    reset_zle_buffer(master_fd)

    # Step 3: Clear the result file
    try:
        open(RESULT_FILE, "w").close()
    except IOError:
        pass

    # Step 4: Type the buffer text into zle (this sets BUFFER)
    send(master_fd, buffer_text.encode())
    time.sleep(0.08)

    # Step 5: Fire the completion widget
    send(master_fd, TRIGGER)

    # Step 6: Poll the result file (no PTY display race)
    results = wait_for_result_file(label, timeout=TIMEOUT_S)

    # Drain PTY display output (prompt redraws, etc.)
    time.sleep(0.15)
    drain(master_fd, 0.1)

    if results is None:
        print(f"  WARN: result file never got END sentinel for {label}.", file=sys.stderr)
        # Dump widget log on failure.
        try:
            with open(LOG_FILE) as lf:
                log_content = lf.read().strip()
            if log_content:
                print(f"  LOG: {log_content}", file=sys.stderr)
        except Exception:
            pass
        # Dump result file contents for diagnosis
        try:
            with open(RESULT_FILE) as rf:
                result_content = rf.read()
            print(f"  RESULT_FILE: {result_content!r}", file=sys.stderr)
        except Exception:
            pass
        # Send ^U to clean up any residual buffer state for next query
        reset_zle_buffer(master_fd)
        return []

    return results


def measure_latency(master_fd, n=30):
    """Measure per-query latency for warm queries (git p), reusing the same shell."""
    home = os.environ.get("HOME", "/")
    times = []
    for i in range(n):
        label = f"lat{i}"
        t0 = time.monotonic()
        run_query(master_fd, label, "git p", home)
        t1 = time.monotonic()
        times.append(t1 - t0)
    times.sort()
    return times


def main():
    sys.stdout.write("== F-4 §0 spike ==\n")
    sys.stdout.write(f"Shell: {ZSH}\n")
    sys.stdout.write(f"Result file: {RESULT_FILE}\n")
    sys.stdout.write(f"Log file: {LOG_FILE}\n\n")
    sys.stdout.flush()

    # Write sidecar script to a temp file
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".zsh", prefix="termy_f4_sidecar_",
        delete=False, encoding="utf-8"
    ) as tf:
        tf.write(SIDECAR_SCRIPT)
        tmpfile_path = tf.name

    master_fd, pid = spawn_zsh()

    try:
        sys.stdout.write("Booting sidecar...\n")
        sys.stdout.flush()
        if not boot_sidecar(master_fd, tmpfile_path):
            sys.stdout.write("FAIL: sidecar boot failed\n")
            sys.stdout.flush()
            sys.exit(1)
        sys.stdout.write("Sidecar ready.\n\n")
        sys.stdout.flush()

        PASS = True
        desc_total = 0
        desc_with = 0
        home = os.environ.get("HOME", "/")

        # === Case 1: git p ===
        sys.stdout.write("Case: git p<Tab>\n")
        sys.stdout.flush()
        results = run_query(master_fd, "git_p", "git p", home)
        n = len(results)
        titles = [r[0] for r in results]
        desc_by_title = {title: desc for title, desc in results}
        widget_state = read_widget_state("git_p")
        sys.stdout.write(f"  candidates: {n}\n")
        sys.stdout.write(f"  sample titles: {titles[:8]}\n")
        sys.stdout.write(f"  pull desc: {desc_by_title.get('pull', '')}\n")
        sys.stdout.write(f"  push desc: {desc_by_title.get('push', '')}\n")
        sys.stdout.write(f"  widget state: {widget_state}\n")
        if widget_state != ("git p", 5, "p"):
            sys.stdout.write(f"  FAIL: widget must see BUFFER='git p', CURSOR=5, PREFIX='p'\n")
            PASS = False
        leaked = [t for t in titles if t in ("nosort", "_e_11")]
        if leaked:
            sys.stdout.write(f"  FAIL: leaked internal compadd flag values: {leaked}\n")
            PASS = False
        non_prefix = [t for t in titles if t and not t.startswith("p")]
        if non_prefix:
            sys.stdout.write(f"  FAIL: non-prefix git candidates for 'git p': {non_prefix[:8]}\n")
            PASS = False
        if not desc_by_title.get("pull", "").startswith("fetch from"):
            sys.stdout.write("  FAIL: pull description must start with 'fetch from'\n")
            PASS = False
        if not desc_by_title.get("push", "").startswith("update remote refs"):
            sys.stdout.write("  FAIL: push description must start with 'update remote refs'\n")
            PASS = False
        if n < 3:
            sys.stdout.write(f"  FAIL: need >=3, got {n}\n")
            PASS = False
        else:
            sys.stdout.write(f"  PASS (>=3)\n")
        desc_total += n
        desc_with += sum(1 for _, d in results if d)
        sys.stdout.write("\n")
        sys.stdout.flush()

        # === Case 2: kubectl get p ===
        sys.stdout.write("Case: kubectl get p<Tab>\n")
        sys.stdout.flush()
        import shutil
        kubectl_path = shutil.which("kubectl")
        if kubectl_path:
            results_k = run_query(master_fd, "kctl_p", "kubectl get p", home)
            nk = len(results_k)
            sys.stdout.write(f"  candidates: {nk}\n")
            sys.stdout.write(f"  sample titles: {[r[0] for r in results_k[:8]]}\n")
            if nk < 3:
                sys.stdout.write(f"  NOTE: kubectl installed but got <3 candidates (completion may need kubeconfig)\n")
            else:
                sys.stdout.write(f"  PASS (>=3)\n")
            desc_total += nk
            desc_with += sum(1 for _, d in results_k if d)
        else:
            sys.stdout.write("  SKIP: kubectl not found on PATH\n")
        sys.stdout.write("\n")
        sys.stdout.flush()
        # After kubectl (which may be slow or timeout), drain PTY to reset state
        drain(master_fd, 0.3)

        # === Case 3: npm run b (only if package.json exists in $HOME) ===
        sys.stdout.write("Case: npm run b<Tab>\n")
        sys.stdout.flush()
        npm_path = shutil.which("npm")
        if npm_path and os.path.isfile(os.path.join(home, "package.json")):
            results_npm = run_query(master_fd, "npm_b", "npm run b", home)
            nn = len(results_npm)
            sys.stdout.write(f"  candidates: {nn}\n")
            if nn < 1:
                sys.stdout.write(f"  NOTE: npm installed with package.json but got 0 candidates\n")
            else:
                sys.stdout.write(f"  PASS (>=1)\n")
            desc_total += nn
            desc_with += sum(1 for _, d in results_npm if d)
        else:
            sys.stdout.write("  SKIP: npm not installed or no package.json in $HOME\n")
        sys.stdout.write("\n")
        sys.stdout.flush()

        # === Case 4: cd ~/Pro ===
        sys.stdout.write("Case: cd ~/Pro<Tab>\n")
        sys.stdout.flush()
        results_cd = run_query(master_fd, "cd_pro", "cd ~/Pro", home)
        ncd = len(results_cd)
        sys.stdout.write(f"  candidates: {ncd}\n")
        sys.stdout.write(f"  sample titles: {[r[0] for r in results_cd[:8]]}\n")
        if ncd < 1:
            sys.stdout.write(f"  FAIL: need >=1, got {ncd}\n")
            PASS = False
        else:
            sys.stdout.write(f"  PASS (>=1)\n")
        desc_total += ncd
        desc_with += sum(1 for _, d in results_cd if d)
        sys.stdout.write("\n")
        sys.stdout.flush()

        # Dump widget log entries.
        sys.stdout.write("Widget log entries:\n")
        try:
            with open(LOG_FILE) as lf:
                for line in lf:
                    sys.stdout.write(f"  {line.rstrip()}\n")
        except Exception as e:
            sys.stdout.write(f"  (could not read log: {e})\n")
        sys.stdout.write("\n")
        sys.stdout.flush()

        # === Description coverage ===
        sys.stdout.write("Description coverage check:\n")
        if desc_total > 0:
            pct = int(100 * desc_with / desc_total)
            sys.stdout.write(f"  {desc_with}/{desc_total} ({pct}%) carry non-empty description\n")
            if pct < 50:
                sys.stdout.write(f"  NOTE: description coverage <50%\n")
            else:
                sys.stdout.write(f"  PASS\n")
        else:
            sys.stdout.write("  N/A (no candidates captured)\n")
            pct = 0
        sys.stdout.write("\n")
        sys.stdout.flush()

        if not PASS:
            sys.stdout.write("=" * 40 + "\n")
            sys.stdout.write("== FAIL (skipping latency measurement) ==\n")
            sys.stdout.flush()
            sys.exit(1)

        # === Warm p95 latency: 30 iters of git p ===
        sys.stdout.write("Measuring warm p95 latency (30 iterations of 'git p')...\n")
        sys.stdout.write("  (this may take ~30s)\n")
        sys.stdout.flush()
        n_lat = 30
        lat_times = measure_latency(master_fd, n_lat)
        p50_ms = lat_times[int(n_lat * 0.50) - 1] * 1000
        p95_ms = lat_times[int(n_lat * 0.95) - 1] * 1000
        p99_ms = lat_times[int(n_lat * 0.99) - 1] * 1000
        sys.stdout.write(f"  p50:  {p50_ms:.1f} ms\n")
        sys.stdout.write(f"  p95:  {p95_ms:.1f} ms\n")
        sys.stdout.write(f"  p99:  {p99_ms:.1f} ms\n")
        if p95_ms > 50:
            sys.stdout.write(f"  NOTE: warm p95 {p95_ms:.1f}ms > 50ms threshold\n")
        else:
            sys.stdout.write(f"  PASS: p95 < 50ms\n")
        sys.stdout.write("\n")

        # === Summary ===
        sys.stdout.write("=" * 40 + "\n")
        sys.stdout.write("== PASS ==\n")
        sys.stdout.flush()
        sys.exit(0)

    finally:
        try:
            os.unlink(tmpfile_path)
        except Exception:
            pass
        for path in (RESULT_FILE, LOG_FILE):
            try:
                os.unlink(path)
            except Exception:
                pass
        try:
            os.close(master_fd)
        except Exception:
            pass
        try:
            os.kill(pid, signal.SIGTERM)
            os.waitpid(pid, 0)
        except Exception:
            pass


if __name__ == "__main__":
    main()
