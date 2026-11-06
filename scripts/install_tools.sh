#!/usr/bin/env bash
# Download and unpack OSS CAD Suite into ~/tools, and add it to PATH via ~/.bashrc.
set -euo pipefail
VER=20261106
TGZ=oss-cad-suite-linux-x64-${VER}.tgz
URL=https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-11-06/${TGZ}
mkdir -p ~/tools && cd ~/tools
if [ ! -d oss-cad-suite ]; then
  [ -f "$TGZ" ] || wget -q "$URL" -O "$TGZ"
  tar -xzf "$TGZ"
  rm -f "$TGZ"
fi
# PATH is set per-run via scripts/env.sh (no shell profile changes).
export PATH="$HOME/tools/oss-cad-suite/bin:$PATH"
yosys -V
sby --help | head -1 || true
echo "solvers:"; for s in bitwuzla boolector yices-smt2 z3; do printf '  %s: ' $s; command -v $s || echo MISSING; done
