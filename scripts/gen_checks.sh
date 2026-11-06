#!/usr/bin/env bash
# Generate riscv-formal check directories for a core and list them.
# Usage: scripts/gen_checks.sh [core]   (default: picorv32_dsq)
# (Runs without make: genchecks.py only needs python3.)
set -euo pipefail
source "$(dirname "$0")/env.sh"
CORE=${1:-picorv32_dsq}
cd "$(dirname "$0")/../riscv-formal/cores/$CORE"
rm -rf checks
python3 ../../checks/genchecks.py
echo "Generated $(ls checks/*.sby | wc -l) checks"
ls checks/*.sby | xargs -n1 basename | sed 's/\.sby$//' | tr '\n' ' '; echo
