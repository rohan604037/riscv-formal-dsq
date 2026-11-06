#!/usr/bin/env bash
# Run the standalone DSQ co-processor proof (prove + cover) and print results.
set -uo pipefail
source "$(dirname "$0")/env.sh"
cd "$(dirname "$0")/../formal/dsq_unit"
sby -f dsq_unit.sby "$@" > run.log 2>&1
grep -E "DONE|Assert failed|Reached cover|Unreached|summary: Elapsed clock|ERROR" run.log
