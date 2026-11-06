#!/usr/bin/env bash
# Live progress bars for all formal runs.
#   bash scripts/progress.sh        -> refresh every 5 s (Ctrl+C to quit)
#   bash scripts/progress.sh once   -> print once and exit
root="$(cd "$(dirname "$0")/.." && pwd)"

bar() {  # bar <label> <done> <total> <fails> <running>
  local label=$1 done=$2 total=$3 fails=$4 running=$5 width=30
  local pct=0; [ "$total" -gt 0 ] && pct=$(( done * 100 / total ))
  local fill=$(( done * width / (total > 0 ? total : 1) ))
  local b; b=$(printf '%*s' "$fill" '' | tr ' ' '#')$(printf '%*s' $(( width - fill )) '' | tr ' ' '-')
  local color=32; [ "$fails" -gt 0 ] && color=31
  printf "  %-26s [\e[${color}m%s\e[0m] %3d%%  %3d/%-3d  fail:%d  running:%d\n" \
         "$label" "$b" "$pct" "$done" "$total" "$fails" "$running"
}

suite() {  # suite <label> <checks-dir>
  local dir=$1/checks total=0 done=0 fails=0 running=0
  [ -d "$dir" ] || return
  for s in "$dir"/*.sby; do
    total=$((total+1)); local n=${s%.sby}
    if [ -f "$n/status" ]; then
      done=$((done+1)); grep -q PASS "$n/status" || fails=$((fails+1))
    elif [ -d "$n" ]; then running=$((running+1)); fi
  done
  bar "$2" "$done" "$total" "$fails" "$running"
  if [ "$running" -gt 0 ]; then
    for s in "$dir"/*.sby; do local n=${s%.sby}
      [ -d "$n" ] && [ ! -f "$n/status" ] && \
        printf "      \e[33m~ %-24s\e[0m %s\n" "$(basename "$n")" \
          "$(grep -oE '[0-9]+:[0-9]{2}:[0-9]{2} +(Checking|waiting|Skipping|Assum|Trying|Running)[^.]*' "$n/logfile.txt" 2>/dev/null | tail -1)"
    done
  fi
}

unit() {  # standalone DSQ unit + mutants
  local u=$root/formal/dsq_unit d=0 f=0
  for t in dsq_unit_prove dsq_unit_cover; do
    [ -f "$u/$t/status" ] && { d=$((d+1)); grep -q PASS "$u/$t/status" || f=$((f+1)); }
  done
  bar "DSQ unit proof+cover" "$d" 2 "$f" 0
  local md=0 mk=0
  for m in "$u"/mutants/mut_*; do [ -f "$m/dsq_unit_prove/status" ] || continue
    md=$((md+1)); grep -q FAIL "$m/dsq_unit_prove/status" && mk=$((mk+1)); done
  bar "Bug injection (caught)" "$mk" 4 $(( md - mk )) 0
}

show() {
  clear 2>/dev/null
  echo -e "\e[1mriscv-formal-dsq progress\e[0m   $(date '+%H:%M:%S')"
  echo
  unit
  suite "$root/riscv-formal/cores/picorv32_dsq" "Tapeout core + DSQ"
  suite "$root/riscv-formal/cores/picorv32"     "Upstream PicoRV32 baseline"
  echo
  echo "  (fail on a mutant row = bug NOT caught; Ctrl+C to quit)"
}

if [ "${1:-}" = once ]; then show; else while true; do show; sleep 5; done; fi
