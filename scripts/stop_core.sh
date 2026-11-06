#!/usr/bin/env bash
# Stop all running sby/solver processes for one core (default picorv32_dsq).
CORE=${1:-picorv32_dsq}
pids=$(pgrep -f "cores/$CORE/checks|$CORE/checks/" || true)
# also catch solver children whose cwd is inside the core's checks dir
for p in $(pgrep -f 'yosys-smtbmc|boolector|bitwuzla|yices|sby' || true); do
  cwd=$(readlink "/proc/$p/cwd" 2>/dev/null)
  case "$cwd" in *"/cores/$CORE/checks"*) pids="$pids $p" ;; esac
done
pids=$(echo $pids | tr ' ' '\n' | sort -u)
[ -n "$pids" ] && kill $pids 2>/dev/null
echo "stopped: $(echo $pids | wc -w) processes for $CORE"
