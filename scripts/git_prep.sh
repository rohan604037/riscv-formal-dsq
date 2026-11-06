#!/usr/bin/env bash
# Vendor riscv-formal as plain source (record upstream commit) and init the project repo.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -d riscv-formal/.git ]; then
  {
    echo "riscv-formal: https://github.com/YosysHQ/riscv-formal @ $(git -C riscv-formal rev-parse HEAD)"
    echo "picorv32:     https://github.com/YosysHQ/picorv32 @ $(git -C picorv32 rev-parse HEAD)"
  } > UPSTREAM.txt
  rm -rf riscv-formal/.git
fi
cat UPSTREAM.txt
[ -d .git ] || git init -q -b main
git config user.name  "Rohan R"
git config user.email "rohanraghu610@gmail.com"
git config core.autocrlf input
git add -A
echo "--- staged: $(git diff --cached --name-only | wc -l) files, $(git diff --cached --stat | tail -1)"
git diff --cached --name-only | grep -v '^riscv-formal/'
echo "--- riscv-formal files we added/changed:"
git diff --cached --name-only | grep -E 'picorv32_dsq|insn_dsq|Xdsq'
du -sh .git 2>/dev/null
