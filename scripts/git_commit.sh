#!/usr/bin/env bash
# Stage everything (respecting .gitignore), show what will be committed, and commit.
set -euo pipefail
cd "$(dirname "$0")/.."
git add -A
# drop anything that was staged before it was added to .gitignore
git ls-files -ci --exclude-standard -z | xargs -0 -r git rm -q --cached
echo "--- non-riscv-formal files:"
git diff --cached --name-only | grep -v '^riscv-formal/' || true
echo "--- our riscv-formal files:"
git diff --cached --name-only | grep -E 'picorv32_dsq|insn_dsq|Xdsq' || true
echo "--- total: $(git diff --cached --name-only | wc -l) files"
echo "--- largest staged files:"
git diff --cached --name-only -z | xargs -0 ls -s 2>/dev/null | sort -rn | head -3
git commit -q -F - <<'EOF'
Formal verification of the tapeout PicoRV32 core and custom DSQ instruction

- riscv-formal suite on the exact tapeout core: 59/59 checks pass
- DSQ co-processor: unbounded k-induction proof + cover, golden model
- Bug injection: 4/4 unit mutants and a CPU-level decode mutant caught
- Findings: PicoRV32 custom IRQ trap path, missing ALTOPS in slow MUL,
  unreset pcpi_wait in picorv32_pcpi_mul (masked by SoC multi-cycle reset)
- Upstream PicoRV32 reference run: 87/87
EOF
git log --oneline -1
du -sh .git
