#!/usr/bin/env bash
# Run every generated check for a core and write a summary to results/<out>.txt
# Usage: scripts/run_all.sh [core] [jobs] [out-name] [exclude-regex]
#   e.g. scripts/run_all.sh picorv32_dsq 6 tapeout '^insn_dsq_ch0$'
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
CORE=${1:-picorv32}; J=${2:-10}; OUT=${3:-baseline}; EXCL=${4:-^$}
checks="$here/../riscv-formal/cores/$CORE/checks"
mkdir -p "$here/../results"
names=$(ls "$checks"/*.sby | xargs -n1 basename | sed 's/\.sby$//' | grep -Ev "$EXCL")
start=$(date +%s)
bash "$here/run_checks.sh" -c "$CORE" -j "$J" $names | sort > "$here/../results/$OUT.txt"
echo "total_wall_seconds: $(( $(date +%s) - start ))" >> "$here/../results/$OUT.txt"
grep -c PASS "$here/../results/$OUT.txt" | sed 's/^/passed: /'
grep -v PASS "$here/../results/$OUT.txt"
