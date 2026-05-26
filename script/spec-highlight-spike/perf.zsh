#!/usr/bin/env zsh
# perf.zsh — per-keystroke performance measurement for termy_spec_classify
# Task 3 of spec-highlight-spike.
#
# Measures:
#   1. COLD / first-call time (includes lazy source of spec_git.zsh)
#   2. Steady-state time averaged over N=1000 cached calls
#
# Timing method: zsh/datetime EPOCHREALTIME (float seconds, sub-millisecond resolution)
# Gate: target <5 ms/call for steady-state; flag if exceeded.

zmodload zsh/datetime

# Source the matcher so its functions are available.
source "${0:A:h}/matcher.zsh"

local N=1000
local LINE='git commit -m "x" --amend'

# ---- Cold call (first call; includes lazy source of spec_git.zsh) ------------
# Ensure no spec is pre-loaded (simulate fresh session state).
unset _TS_LOADED
typeset -gA _TS_LOADED

local t_cold_start=$EPOCHREALTIME
termy_spec_classify "$LINE" > /dev/null
local t_cold_end=$EPOCHREALTIME
local ms_cold=$(( (t_cold_end - t_cold_start) * 1000 ))

# ---- Steady-state: N=1000 cached calls ---------------------------------------
# Spec is already loaded; _TS_LOADED[git] = 1
local t0=$EPOCHREALTIME
local i
for (( i = 0; i < N; i++ )); do
  termy_spec_classify "$LINE" > /dev/null
done
local t1=$EPOCHREALTIME

local ms_total=$(( (t1 - t0) * 1000 ))
local ms_per_call=$(( ms_total / N ))

# ---- Report ------------------------------------------------------------------
printf "Cold (first call, includes spec source): %.3f ms\n" "$ms_cold"
printf "Steady-state (N=%d cached calls):        %.3f ms total  =>  %.4f ms/call\n" \
       "$N" "$ms_total" "$ms_per_call"

# Gate check
local gate=5.0
if (( $(printf '%s < %s\n' "$ms_per_call" "$gate" | bc -l) )); then
  printf "Gate <%g ms/call: PASS\n" "$gate"
else
  printf "Gate <%g ms/call: FAIL (%.4f ms/call exceeds threshold)\n" "$gate" "$ms_per_call"
fi
