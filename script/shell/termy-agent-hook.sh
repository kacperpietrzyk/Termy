#!/bin/sh
# FB-3-2 + FB-3-5 — Termy agent hook (invoked by Claude Code via --settings).
#   termy-agent-hook.sh <state-dir> <session-uuid> <keyword>
# keyword "working"/"waiting" (FB-3-2): atomically record it to
#   <dir>/<uuid>.state for Termy to consume.
# keyword "tool" (FB-3-5): capture the PostToolUse JSON payload (stdin) to
#   <dir>/<uuid>.<pid>.<epoch>.tool.json for plan/touched extraction.
# Never blocks Claude; always drains stdin and exits 0.
dir="$1"
uuid="$2"
kw="$3"
if [ -z "$dir" ] || [ -z "$uuid" ] || [ -z "$kw" ]; then
  cat >/dev/null 2>&1   # drain hook payload on stdin
  exit 0
fi
if [ "$kw" = "tool" ]; then
  tmp="$dir/.$uuid.tool.tmp.$$"
  trap 'rm -f "$tmp"' EXIT
  if cat > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$dir/$uuid.$$.$(date +%s).tool.json" 2>/dev/null
  fi
  exit 0
fi
cat >/dev/null 2>&1   # state keywords ignore the payload
tmp="$dir/.$uuid.state.tmp.$$"
trap 'rm -f "$tmp"' EXIT
if printf '%s' "$kw" > "$tmp" 2>/dev/null; then
  mv -f "$tmp" "$dir/$uuid.state" 2>/dev/null
fi
exit 0
