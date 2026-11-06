#!/usr/bin/env bash
# Run selected riscv-formal checks in parallel with sby (no make needed).
# Usage: scripts/run_checks.sh [-c core] [-j N] check1 check2 ...
#   e.g. scripts/run_checks.sh -c picorv32_dsq -j 4 insn_dsq_ch0 insn_add_ch0
set -uo pipefail
source "$(dirname "$0")/env.sh"
J=4; CORE=picorv32
while [ $# -gt 0 ]; do
  case "$1" in
    -j) J=$2; shift 2 ;;
    -c) CORE=$2; shift 2 ;;
    *) break ;;
  esac
done
cd "$(dirname "$0")/../riscv-formal/cores/$CORE/checks"
printf '%s\n' "$@" | xargs -P "$J" -I{} sh -c 'sby -f {}.sby > {}.log 2>&1; echo "{}: $(cat {}/status 2>/dev/null || echo ERROR)"'
