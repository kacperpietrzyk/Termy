#!/usr/bin/env zsh
# F-4 §0 spike — entry point.
# Delegates to spike.py which uses Python's pty.fork() to give zsh a real
# PTY so zle activates. Running _main_complete outside an active zle
# context returns degraded/empty results for compsys-heavy completions
# (git, docker, kubectl) — this is the mechanism being proved.
#
# Exit 0 on PASS; non-zero on FAIL.

set -euo pipefail
SCRIPT_DIR=${0:A:h}

exec python3 "$SCRIPT_DIR/spike.py" "$@"
