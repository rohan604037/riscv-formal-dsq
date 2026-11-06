#!/usr/bin/env bash
# Report which tools needed for the riscv-formal flow are installed.
for t in git make python3 gcc curl wget tar yosys sby bitwuzla boolector yices-smt2 z3 riscv64-unknown-elf-gcc; do
  p=$(command -v "$t" 2>/dev/null)
  echo "$t: ${p:-MISSING}"
done
