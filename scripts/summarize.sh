#!/usr/bin/env bash
# Rebuild results/<out>.txt from per-check status files.
# Usage: scripts/summarize.sh <core> <out-name>
# status file format: "<PASS|FAIL|ERROR> <rc> <solver-seconds>"
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
CORE=${1:-picorv32}; OUT=${2:-baseline}
dir="$root/riscv-formal/cores/$CORE/checks"
mkdir -p "$root/results"
{
  for s in "$dir"/*.sby; do
    n=$(basename "${s%.sby}")
    if [ -f "$dir/$n/status" ]; then echo "$n: $(cat "$dir/$n/status")"; else echo "$n: NOT_RUN"; fi
  done | sort
} > "$root/results/$OUT.txt"
f="$root/results/$OUT.txt"
total=$(wc -l < "$f"); pass=$(grep -c ': PASS' "$f")
secs=$(awk '/: PASS/{s+=$4} END{print s+0}' "$f")
{
  echo "---"
  echo "core: $CORE"
  echo "checks: $total  passed: $pass  not-passed: $((total-pass))"
  echo "total_solver_seconds: $secs"
} >> "$f"
tail -4 "$f"; grep -v ': PASS' "$f" | grep -v -E '^---|^core|^checks|^total' || true
