#!/usr/bin/env bash
# Bug injection: run the DSQ unit properties against each mutant (expect FAIL).
# A mutant that still PASSES means the property set has a hole.
set -uo pipefail
source "$(dirname "$0")/env.sh"
cd "$(dirname "$0")/../formal/dsq_unit"
mkdir -p mutants
out=mutants/summary.txt; : > "$out"
for m in ${@:-mut_signed mut_drop_lane mut_narrow_diff mut_no_seen}; do
  d=mutants/$m; rm -rf "$d"; mkdir -p "$d"
  cp "$m.v" "$d/pcpi_dsq_tapeout.v"; cp dsq_unit_props.sv "$d/"
  # BMC deep enough that clocked asserts (checked one cycle late by Yosys) can fire
  sed -e 's/^prove: mode prove/prove: mode bmc/' -e 's/^prove: depth .*/prove: depth 8/' dsq_unit.sby > "$d/dsq_unit.sby"
  ( cd "$d" && sby -f dsq_unit.sby prove > run.log 2>&1 )
  status=$(grep -oE "DONE \((PASS|FAIL|ERROR)" "$d/run.log" | tail -1 | sed 's/DONE (//')
  prop=$(grep -m1 -oE "Assert failed in dsq_unit_props: dsq_unit_props.sv:[0-9]+" "$d/run.log" | sed 's/.*sv:/line /')
  step=$(grep -m1 -oE "BMC failed!|Assert failed .*step [0-9]+|failed in step [0-9]+" "$d/run.log")
  echo "$m: $status ${prop:+(caught by $prop)}" | tee -a "$out"
done
