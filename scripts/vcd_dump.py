#!/usr/bin/env python3
"""Print a cycle-by-cycle table of selected signals from an SBY counterexample VCD.

Usage: vcd_dump.py trace.vcd [--from N] [--to M] pattern [pattern ...]
A pattern matches if it is a substring of the full hierarchical signal name.
Values are shown in hex; one row per clock step (rising edges of the first 'clock').
"""
import sys

def parse(path):
    sigs, scope, ids = {}, [], {}
    changes = []  # (time, id, value)
    t = 0
    with open(path) as f:
        in_defs = True
        for line in f:
            tok = line.split()
            if not tok:
                continue
            if in_defs:
                if tok[0] == "$scope":
                    scope.append(tok[2])
                elif tok[0] == "$upscope":
                    scope.pop()
                elif tok[0] == "$var":
                    width, ident, name = int(tok[2]), tok[3], tok[4]
                    full = ".".join(scope + [name])
                    ids.setdefault(ident, []).append(full)
                    sigs[full] = (ident, width)
                elif tok[0] == "$enddefinitions":
                    in_defs = False
                continue
            c = tok[0]
            if c[0] == "#":
                t = int(c[1:])
            elif c[0] in "01xz" and len(tok) == 1:
                changes.append((t, c[1:], c[0]))
            elif c[0] in "bB":
                changes.append((t, tok[1], c[1:]))
    return sigs, changes

def main():
    args = sys.argv[1:]
    path = args.pop(0)
    lo, hi = 0, 10**9
    pats = []
    while args:
        a = args.pop(0)
        if a == "--from": lo = int(args.pop(0))
        elif a == "--to": hi = int(args.pop(0))
        else: pats.append(a)
    sigs, changes = parse(path)
    chosen = []
    for p in pats:
        hits = sorted((n for n in sigs if n.endswith(p) or ("." + p) in n), key=len)
        if hits:
            chosen.append(hits[0])
        else:
            print(f"# no signal matching {p}", file=sys.stderr)
    times = sorted({t for t, _, _ in changes})
    # SBY VCDs use one time unit per half clock (steps at multiples of 10); sample per distinct time
    val = {}
    idmap = {sigs[n][0]: n for n in chosen}
    rows = []
    ci = 0
    for t in times:
        while ci < len(changes) and changes[ci][0] == t:
            _, ident, v = changes[ci]
            if ident in idmap:
                val[idmap[ident]] = v
            ci += 1
        rows.append((t, dict(val)))
    # keep only times on step boundaries (even multiples of the smallest step)
    step = min((b - a) for a, b in zip(times, times[1:]) if b > a) if len(times) > 1 else 1
    short = [n.split(".")[-1] for n in chosen]
    print("t    " + "  ".join(f"{s:>12}" for s in short))
    for t, v in rows:
        k = t // step
        if not (lo <= k <= hi):
            continue
        out = []
        for n in chosen:
            x = v.get(n, "?")
            try:
                x = format(int(x, 2), "x")
            except ValueError:
                pass
            out.append(f"{x:>12}")
        print(f"{k:<4} " + "  ".join(out))

if __name__ == "__main__":
    main()
